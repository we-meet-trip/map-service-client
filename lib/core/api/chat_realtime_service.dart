import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../config/app_config.dart';
import '../state/auth_store.dart';

/// 채팅 실시간 연결의 상태.
///
/// [authRequired] 는 토큰을 새로 받아도 거절당한 상태다. 다시 붙어 봐야
/// 같은 결과라 재연결을 멈추고 화면이 로그인을 요구해야 한다.
enum ChatConnectionState {
  idle,
  connecting,
  connected,
  disconnected,
  authRequired,
}

/// 실시간 프레임의 종류.
///
/// [unknown] 은 서버가 나중에 새 종류를 늘렸을 때를 위한 자리다. 모르는 값을
/// 만나 예외를 던지면 이미 배포된 앱이 죽으므로, 해석만 포기하고 흘려보낸다.
enum ChatEventKind {
  message,
  messageRemoved,
  system,
  read,
  typing,
  presence,
  roomClosed,
  error,
  unknown,
}

/// 해석된 실시간 프레임 하나.
class ChatEvent {
  /// 프레임 종류.
  final ChatEventKind kind;

  /// 어느 방의 사건인지. 오류 프레임에는 없다.
  final int? roomId;

  /// 사람이 읽을 사유. 오류 프레임에서만 채워진다.
  final String? reason;

  /// 종류별 본문.
  ///
  /// 방 브로드캐스트는 감싼 봉투를 벗긴 안쪽이고, 오류 프레임은 code 와
  /// destination 이 최상위에 있으므로 프레임 자체가 그대로 본문이 된다.
  final Map<String, dynamic>? data;

  const ChatEvent({required this.kind, this.roomId, this.reason, this.data});

  factory ChatEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    final kind = _kindOf(type);

    if (kind == ChatEventKind.error) {
      return ChatEvent(
        kind: kind,
        reason: json['message'] as String?,
        data: json,
      );
    }

    return ChatEvent(
      kind: kind,
      roomId: (json['room_id'] as num?)?.toInt(),
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  /// 봉투 없이 곧바로 프레임 본문을 받는 경로.
  ///
  /// 브로커가 주는 문자열은 언제든 깨져 올 수 있다. 여기서 던지면 소켓을 듣던
  /// 쪽이 통째로 끊기므로, 해석에 실패하면 알 수 없는 종류로 흘려보낸다.
  static ChatEvent parse(String? body) {
    if (body == null || body.isEmpty) {
      return const ChatEvent(kind: ChatEventKind.unknown);
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return const ChatEvent(kind: ChatEventKind.unknown);
      }
      return ChatEvent.fromJson(decoded);
    } catch (_) {
      return const ChatEvent(kind: ChatEventKind.unknown);
    }
  }

  static ChatEventKind _kindOf(String? type) {
    switch (type) {
      case 'MESSAGE':
        return ChatEventKind.message;
      case 'MESSAGE_REMOVED':
        return ChatEventKind.messageRemoved;
      case 'SYSTEM':
        return ChatEventKind.system;
      case 'READ':
        return ChatEventKind.read;
      case 'TYPING':
        return ChatEventKind.typing;
      case 'PRESENCE':
        return ChatEventKind.presence;
      case 'ROOM_CLOSED':
        return ChatEventKind.roomClosed;
      case 'ERROR':
        return ChatEventKind.error;
      default:
        return ChatEventKind.unknown;
    }
  }
}

/// 방 하나에 붙어 있는 실시간 연결.
///
/// 인증은 핸드셰이크가 아니라 STOMP CONNECT 프레임의 헤더로 한다. 브라우저는
/// 소켓을 열 때 헤더를 붙일 수단이 없어서, 붙일 수 있는 첫 지점이 CONNECT 다.
///
/// 헤더 맵을 다시 만들지 않고 같은 맵의 값만 갈아 끼우는 이유: 연결 직전마다
/// 이 맵을 펼쳐 프레임을 만들기 때문에, 값만 바꿔 두면 다시 붙을 때 새 토큰이
/// 저절로 실린다. 토큰이 바뀔 때마다 연결을 새로 만들 필요가 없다.
///
/// 끊겼다 붙는 사이의 사건은 되돌려 받을 수 없다. 브로커가 지난 것을 다시
/// 보내 주지 않기 때문이다. 그래서 다시 붙으면 화면이 REST 로 지난 대화를
/// 새로 읽어야 하고, 그 신호로 [reconnected] 를 흘린다.
class ChatRealtimeService {
  ChatRealtimeService();

  static const _baseBackoff = Duration(milliseconds: 500);
  static const _maxBackoff = Duration(seconds: 30);

  final _events = StreamController<ChatEvent>.broadcast();
  final _states = StreamController<ChatConnectionState>.broadcast();
  final _reconnected = StreamController<void>.broadcast();

  /// 방 방송과 개인 오류를 한 줄기로 합쳐 흘린다.
  Stream<ChatEvent> get events => _events.stream;

  /// 연결 상태 변화.
  Stream<ChatConnectionState> get states => _states.stream;

  /// 끊겼다 다시 붙은 순간. 받는 쪽은 지난 대화를 다시 읽어야 한다.
  Stream<void> get reconnected => _reconnected.stream;

  final Map<String, String> _connectHeaders = {};

  final _random = Random();

  StompClient? _client;
  int? _roomId;
  bool _hadConnected = false;
  bool _refreshedForThisFailure = false;
  int _attempt = 0;
  ChatConnectionState _state = ChatConnectionState.idle;

  ChatConnectionState get state => _state;
  bool get isConnected => _state == ChatConnectionState.connected;

  /// 접속할 소켓 주소.
  static Uri endpoint() => endpointFor(kApiBaseUrl);

  /// 서버 주소에서 소켓 주소를 파생한다.
  ///
  /// 스킴을 주소에 맞춰 고르는 이유: 안전한 연결로 연 화면에서 평문 소켓을
  /// 열면 브라우저가 그 연결을 막아 채팅만 조용히 죽는다.
  static Uri endpointFor(String baseUrl) {
    final base = Uri.parse(baseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return base.replace(scheme: scheme, path: '/ws/chat');
  }

  /// 방에 붙는다. 이미 같은 방에 붙어 있으면 아무것도 하지 않는다.
  void connect(int roomId) {
    if (_client != null && _roomId == roomId) return;
    disconnect();

    _roomId = roomId;
    _hadConnected = false;
    _refreshedForThisFailure = false;
    _attempt = 0;
    _emit(ChatConnectionState.connecting);

    _client = StompClient(
      config: StompConfig(
        url: endpoint().toString(),
        stompConnectHeaders: _connectHeaders,
        // 실제 기다림은 beforeConnect 가 맡는다. 여기는 재시도를 걸어 두기만
        // 하는 최소 간격이다.
        reconnectDelay: const Duration(milliseconds: 200),
        heartbeatIncoming: const Duration(seconds: 10),
        heartbeatOutgoing: const Duration(seconds: 10),
        connectionTimeout: const Duration(seconds: 10),
        beforeConnect: _beforeConnect,
        onConnect: _onConnect,
        onStompError: _onStompError,
        onWebSocketDone: _onDone,
        onWebSocketError: (_) => _emit(ChatConnectionState.disconnected),
      ),
    )..activate();
  }

  /// 연결 직전마다 지금 가진 토큰을 헤더에 싣는다.
  ///
  /// 서버가 죽어 있을 때 같은 간격으로 계속 두드리면 그 자체가 부담이 되므로,
  /// 실패가 이어질수록 간격을 늘린다. 여러 기기가 동시에 끊겼을 때 한꺼번에
  /// 몰려 붙지 않도록 흔들림을 섞는다. 이 기다림을 여기서 하는 이유는 이
  /// 함수가 매 연결 시도 직전에 불리기 때문이다.
  ///
  /// 직전 시도가 인증으로 거절됐다면 여기서 한 번만 토큰을 새로 받아 본다.
  /// 갱신까지 실패하면 더 붙어 봐야 같은 결과이므로 재연결을 멈춘다.
  Future<void> _beforeConnect() async {
    if (_attempt > 0) {
      await Future<void>.delayed(_backoff());
    }
    _attempt += 1;

    if (_refreshedForThisFailure) {
      final renewed = await AuthStore.instance.refresh();
      if (!renewed) {
        _emit(ChatConnectionState.authRequired);
        _client?.deactivate();
        return;
      }
      _refreshedForThisFailure = false;
    }

    final token = AuthStore.instance.accessToken;
    if (token == null) {
      _emit(ChatConnectionState.authRequired);
      _client?.deactivate();
      return;
    }
    _connectHeaders['Authorization'] = 'Bearer $token';

    // 붙기 전까지 기다리는 시간이 길어질 수 있으므로 상태를 미리 알린다.
    _emit(ChatConnectionState.connecting);
  }

  void _onConnect(StompFrame _) {
    final roomId = _roomId;
    if (roomId == null) return;

    final client = _client;
    if (client == null) return;

    // 구독 주소에 와일드카드를 쓰면 서버가 거절한다. 방 번호를 그대로 적는다.
    client.subscribe(
      destination: '/topic/rooms/$roomId',
      callback: (frame) => _events.add(ChatEvent.parse(frame.body)),
    );
    client.subscribe(
      destination: '/user/queue/errors',
      callback: (frame) => _events.add(ChatEvent.parse(frame.body)),
    );

    final wasReconnect = _hadConnected;
    _hadConnected = true;
    _attempt = 0;
    _emit(ChatConnectionState.connected);
    if (wasReconnect) _reconnected.add(null);
  }

  Duration _backoff() {
    final grown = _baseBackoff.inMilliseconds * pow(2, _attempt - 1);
    final capped = min(grown.toDouble(), _maxBackoff.inMilliseconds.toDouble());
    // 흔들림은 계산된 간격의 0~25% 를 더하는 식으로 준다.
    final jitter = _random.nextDouble() * capped * 0.25;
    return Duration(milliseconds: (capped + jitter).round());
  }

  /// 서버가 보낸 STOMP 오류.
  ///
  /// 한 번도 붙은 적 없는 상태에서의 오류는 CONNECT 거절로 본다. 그 사유는
  /// 대개 토큰이라, 다음 시도 전에 갱신을 한 번 시켜 본다.
  void _onStompError(StompFrame frame) {
    if (!_hadConnected) {
      _refreshedForThisFailure = true;
      return;
    }
    _events.add(ChatEvent.parse(frame.body));
  }

  void _onDone() {
    if (_state != ChatConnectionState.authRequired) {
      _emit(ChatConnectionState.disconnected);
    }
  }

  void sendMessage(int roomId, String content, String clientMsgId) {
    _send('/app/rooms/$roomId/send', {
      'content': content,
      'client_msg_id': clientMsgId,
    });
  }

  void markRead(int roomId, int lastReadSeq) {
    _send('/app/rooms/$roomId/read', {'last_read_seq': lastReadSeq});
  }

  void sendTyping(int roomId, bool typing) {
    _send('/app/rooms/$roomId/typing', {'typing': typing});
  }

  /// 소켓이 끊겨 있으면 조용히 버린다.
  ///
  /// 여기서 예외를 던지면 입력창이 죽는다. 보낸 것이 실제로 남았는지는 방
  /// 방송이 돌아오는지로 판정하고, 못 보낸 경우의 대비는 부르는 쪽이 REST 로
  /// 한다.
  bool _send(String destination, Map<String, dynamic> body) {
    final client = _client;
    if (client == null || !client.connected) return false;
    client.send(destination: destination, body: jsonEncode(body));
    return true;
  }

  void disconnect() {
    _client?.deactivate();
    _client = null;
    _roomId = null;
    _hadConnected = false;
    if (_state != ChatConnectionState.idle) {
      _emit(ChatConnectionState.disconnected);
    }
  }

  void dispose() {
    disconnect();
    _events.close();
    _states.close();
    _reconnected.close();
  }

  void _emit(ChatConnectionState next) {
    if (_state == next) return;
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }
}
