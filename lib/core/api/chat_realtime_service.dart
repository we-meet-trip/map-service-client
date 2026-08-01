import 'dart:async';
import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../state/auth_store.dart';
import 'api_client.dart';

/// 대화방 실시간 연결.
///
/// 서버는 **원시 STOMP** 를 쓴다(SockJS 가 아니다). 인증은 연결을 여는
/// 순간이 아니라 **접속 프레임의 헤더**로 한다 — 앱에서는 연결을 여는
/// 요청에 헤더를 붙이기 어려운 경우가 있어 서버가 그렇게 열어 두었다.
///
/// 구독은 **자기 방 하나만** 한다. 별표 같은 넓은 구독은 서버가 거절하고
/// 연결을 끊는다. 거절은 오류 프레임으로 오므로, 그때는 같은 자리에서
/// 다시 붙지 않고 자격을 다시 확인해야 한다.
///
/// 보낸 메시지에는 응답이 오지 않는다. 자기 메시지도 방송으로 돌아오는 것을
/// 받아 확정한다.
class ChatRealtimeService {
  ChatRealtimeService._();
  static final ChatRealtimeService instance = ChatRealtimeService._();

  StompClient? _client;
  String? _roomId;
  StreamController<ChatEvent>? _events;

  /// 방 하나에 붙는다. 이미 다른 방에 붙어 있으면 떼고 새로 붙는다.
  ///
  /// 반환: 그 방에서 일어나는 일이 흘러나오는 스트림.
  Stream<ChatEvent> connect(String roomId) {
    if (_roomId == roomId && _events != null) {
      return _events!.stream;
    }
    disconnect();

    final token = AuthStore.instance.accessToken;
    if (token == null) {
      // 로그인하지 않았으면 붙을 수 없다. 빈 스트림을 주고 화면이 이력만
      // 그리게 한다.
      final empty = StreamController<ChatEvent>.broadcast();
      _events = empty;
      _roomId = roomId;
      return empty.stream;
    }

    final events = StreamController<ChatEvent>.broadcast();
    _events = events;
    _roomId = roomId;

    _client = StompClient(
      config: StompConfig(
        url: _wsUrl(),
        // 접속 프레임에 토큰을 싣는다. 연결 자체는 인증 없이 열리고,
        // 여기서 신원을 밝힌다.
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        onConnect: (_) => _subscribe(roomId, events),
        onWebSocketError: (e) => events.add(
          ChatEvent.disconnected('연결이 끊어졌어요.'),
        ),
        onStompError: (frame) => events.add(
          // 구독 거절·인증 실패가 여기로 온다. 다시 붙어도 같은 결과라
          // 화면이 자격을 다시 확인하도록 알린다.
          ChatEvent.rejected(frame.headers['message'] ?? '대화방에 들어갈 수 없어요.'),
        ),
        // 서버가 끊었을 때 무한히 다시 붙지 않는다 — 거절당한 경우에도
        // 계속 붙으면 소켓만 반복해서 열린다.
        reconnectDelay: Duration.zero,
      ),
    )..activate();

    return events.stream;
  }

  void _subscribe(String roomId, StreamController<ChatEvent> events) {
    _client?.subscribe(
      destination: '/topic/rooms/$roomId',
      callback: (frame) {
        final body = frame.body;
        if (body == null || body.isEmpty) return;
        try {
          final json = jsonDecode(body) as Map<String, dynamic>;
          events.add(ChatEvent.fromJson(json));
        } on FormatException {
          // 알아볼 수 없는 프레임은 버린다.
        }
      },
    );
    events.add(const ChatEvent(kind: ChatEventKind.connected));
  }

  /// 실시간 경로로 메시지를 보낸다. 응답은 없고 방송으로 돌아온다.
  void send(String roomId, String content) {
    _client?.send(
      destination: '/app/rooms/$roomId/send',
      body: jsonEncode({'content': content}),
    );
  }

  /// 여기까지 읽었다고 실시간으로 알린다.
  void markRead(String roomId, int lastReadSeq) {
    _client?.send(
      destination: '/app/rooms/$roomId/read',
      body: jsonEncode({'last_read_seq': lastReadSeq}),
    );
  }

  void disconnect() {
    _client?.deactivate();
    _client = null;
    _events?.close();
    _events = null;
    _roomId = null;
  }

  /// 서버 주소를 실시간 연결 주소로 바꾼다.
  static String _wsUrl() {
    final base = Uri.parse(kApiBaseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return base.replace(scheme: scheme, path: '/ws/chat').toString();
  }
}

enum ChatEventKind { connected, message, system, read, typing, presence, closed, rejected, disconnected }

/// 대화방에서 일어난 일 하나.
class ChatEvent {
  final ChatEventKind kind;
  final Map<String, dynamic>? data;
  final String? reason;

  const ChatEvent({required this.kind, this.data, this.reason});

  factory ChatEvent.rejected(String reason) =>
      ChatEvent(kind: ChatEventKind.rejected, reason: reason);

  factory ChatEvent.disconnected(String reason) =>
      ChatEvent(kind: ChatEventKind.disconnected, reason: reason);

  factory ChatEvent.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return ChatEvent(
      kind: switch (json['type']) {
        'MESSAGE' => ChatEventKind.message,
        'SYSTEM' => ChatEventKind.system,
        'READ' => ChatEventKind.read,
        'TYPING' => ChatEventKind.typing,
        'PRESENCE' => ChatEventKind.presence,
        'ROOM_CLOSED' => ChatEventKind.closed,
        _ => ChatEventKind.message,
      },
      data: data is Map<String, dynamic> ? data : null,
    );
  }
}
