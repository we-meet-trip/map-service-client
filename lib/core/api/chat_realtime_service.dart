import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import '../state/auth_store.dart';

/// 실시간 사건의 종류.
///
/// 모르는 값을 unknown 으로 접는 이유는, 서버가 새 종류를 더했을 때 옛 앱이
/// 예외로 죽지 않게 하려는 것이다.
enum ChatEventKind {
  message,
  system,
  read,
  typing,
  presence,
  roomClosed,
  error,
  reconnected,
  unknown,
}

/// 서버가 흘려보내는 사건 하나.
///
/// 방 방송과 개인 오류 통지는 모양이 다르다. 방 방송은 본문이 data 로 싸여
/// 오지만, 오류는 code·message·status·destination 이 최상위에 실린다.
/// 그 차이를 여기서 접어, 받는 쪽은 kind 만 보면 되게 한다.
class ChatEvent {
  const ChatEvent({
    required this.kind,
    required this.type,
    required this.roomId,
    this.data,
    this.reason,
  });

  final ChatEventKind kind;
  final String type;
  final int roomId;
  final Map<String, dynamic>? data;

  /// 사람에게 보여 줄 사유. 오류 통지에만 담긴다.
  final String? reason;

  factory ChatEvent.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] as String?) ?? 'UNKNOWN';
    final kind = _kindOf(type);
    final roomId = (json['room_id'] as num?)?.toInt() ?? 0;
    if (kind == ChatEventKind.error) {
      // 오류는 싸개가 없다. 프레임 전체를 그대로 넘겨야 code·destination 이
      // 남는다 — 어느 요청이 왜 거절됐는지가 그 둘에 들어 있다.
      return ChatEvent(
        kind: kind,
        type: type,
        roomId: roomId,
        data: json,
        reason: json['message'] as String?,
      );
    }
    final data = json['data'];
    return ChatEvent(
      kind: kind,
      type: type,
      roomId: roomId,
      data: data is Map<String, dynamic> ? data : null,
    );
  }

  static ChatEventKind _kindOf(String type) => switch (type) {
        'MESSAGE' => ChatEventKind.message,
        'SYSTEM' => ChatEventKind.system,
        'READ' => ChatEventKind.read,
        'TYPING' => ChatEventKind.typing,
        'PRESENCE' => ChatEventKind.presence,
        'ROOM_CLOSED' => ChatEventKind.roomClosed,
        'ERROR' => ChatEventKind.error,
        'RECONNECTED' => ChatEventKind.reconnected,
        _ => ChatEventKind.unknown,
      };
}

/// 방 하나의 실시간 연결.
///
/// STOMP 프레임을 직접 만든다. 필요한 명령이 넷뿐이라 라이브러리를 더하지
/// 않았고, 무엇보다 아래 두 가지를 이 자리에서 직접 다뤄야 하기 때문이다.
///
/// 1) 하트비트 — 이동통신망의 중간 장비는 오가는 것이 없는 연결을 걷어간다.
///    그때 양쪽 다 끊긴 줄 모르므로, 보내는 쪽은 죽은 소켓으로 계속 보낸다.
///    주기적으로 한 글자를 보내 연결을 살려 두고, 들어오는 것이 끊기면
///    끊긴 것으로 보고 다시 붙는다.
/// 2) 죽은 연결 판정 — 소켓이 '열려 있음'을 믿으면 안 된다. 마지막으로 무언가
///    받은 시각을 재서, 약속한 주기의 두 배 동안 아무것도 없으면 끊는다.
class ChatRealtimeService {
  ChatRealtimeService({WebSocketChannel Function(Uri)? connector})
      : _connect = connector ?? WebSocketChannel.connect;

  final WebSocketChannel Function(Uri) _connect;

  static const _nul = '\x00';
  static const _clientBeatMs = 10000;
  static const _maxBackoffMs = 30000;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _beatTimer;
  Timer? _watchdog;
  final _events = StreamController<ChatEvent>.broadcast();

  int? _roomId;
  int _attempt = 0;
  bool _closedByCaller = false;
  bool _everConnected = false;
  DateTime _lastInbound = DateTime.fromMillisecondsSinceEpoch(0);

  Stream<ChatEvent> get events => _events.stream;

  /// 소켓이 살아 있다고 볼 수 있는지. 열려 있는지가 아니라, 최근에 무언가를
  /// 받았는지를 본다 — 반쯤 죽은 연결을 열린 것으로 세면 보낸 말이 사라진다.
  bool get isConnected => _channel != null && _watchdogAlive;

  bool get _watchdogAlive =>
      DateTime.now().difference(_lastInbound).inMilliseconds < _clientBeatMs * 3;

  /// 목적지 주소. 서버 주소가 https 면 wss 로 간다 — iOS 는 평문 소켓을
  /// 아예 열어 주지 않으므로 이 파생이 곧 실기기 동작 여부를 가른다.
  static Uri endpointFor(String baseUrl) {
    final base = Uri.parse(baseUrl);
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '/ws/chat',
      query: null,
    );
  }

  Future<void> connect(int roomId) async {
    _closedByCaller = false;
    if (_roomId != roomId) {
      await _teardown();
      _roomId = roomId;
      _attempt = 0;
    }
    await _open();
  }

  Future<void> disconnect() async {
    _closedByCaller = true;
    await _teardown();
  }

  /// 말을 소켓으로 보낸다. 살아 있지 않으면 false 를 돌려주어 부르는 쪽이
  /// REST 로 되돌아갈 수 있게 한다.
  bool send(String content, String clientMsgId) {
    final channel = _channel;
    final roomId = _roomId;
    if (channel == null || roomId == null || !isConnected) {
      return false;
    }
    channel.sink.add(_frame('SEND', {'destination': '/app/rooms/$roomId/send'},
        jsonEncode({'content': content, 'client_msg_id': clientMsgId})));
    return true;
  }

  Future<void> _open() async {
    final roomId = _roomId;
    if (roomId == null || _closedByCaller) {
      return;
    }
    final token = AuthStore.instance.accessToken;
    if (token == null) {
      return;
    }
    try {
      final channel = _connect(endpointFor(kApiBaseUrl));
      _channel = channel;
      _lastInbound = DateTime.now();
      _sub = channel.stream.listen(_onData,
          onError: (_) => _scheduleReconnect(), onDone: _scheduleReconnect);
      channel.sink.add(_frame('CONNECT', {
        'accept-version': '1.2',
        'host': 'map',
        'heart-beat': '$_clientBeatMs,$_clientBeatMs',
        'Authorization': 'Bearer $token',
      }));
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onData(dynamic raw) {
    _lastInbound = DateTime.now();
    final text = raw is List<int> ? utf8.decode(raw) : raw.toString();
    // 하트비트는 개행 한 글자로 온다. 받았다는 사실만 의미가 있다.
    if (text.trim().isEmpty) {
      return;
    }
    for (final piece in text.split(_nul)) {
      if (piece.trim().isEmpty) {
        continue;
      }
      _onFrame(piece);
    }
  }

  void _onFrame(String raw) {
    final split = raw.indexOf('\n\n');
    if (split < 0) {
      return;
    }
    final head = raw.substring(0, split).split('\n');
    final body = raw.substring(split + 2);
    final command = head.first.trim();
    final headers = <String, String>{};
    for (final line in head.skip(1)) {
      final at = line.indexOf(':');
      if (at > 0) {
        headers[line.substring(0, at)] = line.substring(at + 1);
      }
    }

    if (command == 'CONNECTED') {
      _onConnected(headers);
      return;
    }
    if (command == 'MESSAGE') {
      _emit(body);
      return;
    }
    if (command == 'ERROR') {
      // 접속·구독을 거절할 때 서버가 연결을 닫으며 보낸다. 사유를 올려보내고
      // 다시 붙이는 것은 onDone 에 맡긴다.
      _events.add(ChatEvent(
        kind: ChatEventKind.error,
        type: 'ERROR',
        roomId: _roomId ?? 0,
        data: headers,
        reason: headers['message'],
      ));
    }
  }

  void _onConnected(Map<String, String> headers) {
    _attempt = 0;
    final beat = (headers['heart-beat'] ?? '0,0').split(',');
    final serverSends = int.tryParse(beat.first.trim()) ?? 0;
    final serverWants = beat.length > 1 ? int.tryParse(beat[1].trim()) ?? 0 : 0;

    // 내가 보낼 주기는 내가 낼 수 있는 값과 서버가 받고 싶어 하는 값 중 큰 쪽이다.
    final sendEvery = serverWants == 0 ? 0 : max(_clientBeatMs, serverWants);
    // 들어오는 것이 이 주기의 두 배 동안 없으면 끊긴 것으로 본다.
    final expectEvery = serverSends == 0 ? 0 : max(_clientBeatMs, serverSends);

    _beatTimer?.cancel();
    if (sendEvery > 0) {
      _beatTimer = Timer.periodic(Duration(milliseconds: sendEvery),
          (_) => _channel?.sink.add('\n'));
    }
    _watchdog?.cancel();
    if (expectEvery > 0) {
      _watchdog = Timer.periodic(Duration(milliseconds: expectEvery), (_) {
        if (DateTime.now().difference(_lastInbound).inMilliseconds >
            expectEvery * 2) {
          _scheduleReconnect();
        }
      });
    }

    final roomId = _roomId;
    if (roomId != null) {
      _channel?.sink.add(_frame('SUBSCRIBE',
          {'id': 'room-$roomId', 'destination': '/topic/rooms/$roomId'}));
      // 거절된 전송은 방 방송이 아니라 보낸 사람 한 명에게만 온다. 이 구독이
      // 없으면 서버가 되돌려 준 사유가 통째로 사라지고, 화면에는 보낸 것처럼
      // 남은 말풍선만 남는다.
      _channel?.sink.add(_frame(
          'SUBSCRIBE', {'id': 'errors-$roomId', 'destination': '/user/queue/errors'}));
      if (_everConnected) {
        // 브로커는 끊긴 동안의 말을 다시 주지 않는다. 다시 붙었다는 사실만
        // 알리고, 빈 구간을 메우는 것은 기록을 다시 읽는 쪽의 몫으로 둔다.
        _events.add(ChatEvent(
            kind: ChatEventKind.reconnected, type: 'RECONNECTED', roomId: roomId));
      }
      _everConnected = true;
    }
  }

  void _emit(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        _events.add(ChatEvent.fromJson(decoded));
      }
    } on FormatException {
      // 형식이 어긋난 프레임 하나 때문에 연결을 버리지 않는다.
    }
  }

  void _scheduleReconnect() {
    if (_closedByCaller) {
      return;
    }
    _dropSocket();
    _attempt += 1;
    // 지수 대기에 흔들림을 섞는다. 서버가 한 번 내려갔다 올라올 때 모든 기기가
    // 같은 순간에 몰려드는 것을 흩는다.
    final base = min(500 * (1 << min(_attempt, 6)), _maxBackoffMs);
    final jitter = Random().nextInt(max(1, base ~/ 4));
    Timer(Duration(milliseconds: base + jitter), _open);
  }

  void _dropSocket() {
    _beatTimer?.cancel();
    _beatTimer = null;
    _watchdog?.cancel();
    _watchdog = null;
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
  }

  Future<void> _teardown() async {
    _dropSocket();
    _roomId = null;
    _everConnected = false;
  }

  static String _frame(String command, Map<String, String> headers,
      [String body = '']) {
    final head = headers.entries.map((e) => '${e.key}:${e.value}').join('\n');
    return '$command\n$head\n\n$body$_nul';
  }
}
