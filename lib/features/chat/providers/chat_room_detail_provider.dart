import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/chat_api_service.dart';
import '../../../core/api/chat_realtime_service.dart';
import '../../../core/state/auth_store.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/repositories/api_chat_repository.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/repositories/invite_link_repository.dart';

/// 방 하나를 열어 두는 동안의 상태.
///
/// 대화는 두 경로로 들어온다. 지난 것은 REST 로 읽고, 새로 오는 것은 소켓으로
/// 받는다. 끊겼다 붙는 사이의 것은 어느 쪽으로도 오지 않으므로, 다시 붙을 때마다
/// 지난 대화를 새로 읽어 메운다.
class ChatRoomDetailProvider extends ChangeNotifier {
  ChatRoomDetailProvider(
    this._chatRepository,
    this._inviteLinkRepository,
    this.roomId, {
    ChatRealtimeService? realtime,
  }) : _realtime = realtime ?? ChatRealtimeService();

  final ChatRepository _chatRepository;
  final InviteLinkRepository _inviteLinkRepository;
  final ChatRealtimeService _realtime;
  final int roomId;

  StreamSubscription<ChatEvent>? _eventSub;
  StreamSubscription<ChatConnectionState>? _stateSub;
  StreamSubscription<void>? _reconnectSub;

  List<ChatMessage> _messages = [];
  bool isLoading = false;

  /// 실시간 연결이 거절되었거나 끊어진 사유. 화면이 안내에 쓴다.
  String? realtimeNotice;

  /// 서버가 전송을 거절한 사유. 화면이 한 번 보여주고 지우는 값이라
  /// 읽는 쪽에서 consumeSendError 로 가져간다.
  String? _sendError;

  /// 보관 상태로 넘어간 방. 입력창을 닫아야 한다.
  bool isReadOnly = false;

  /// 발급해 둔 초대 링크.
  ///
  /// 화면 단위로 들고 있는다. 발급은 부를 때마다 이전 링크를 죽이므로, 시트를
  /// 열 때마다 새로 부르면 방금 친구에게 보낸 주소가 매번 끊긴다.
  InviteLink? _inviteLink;

  int _sendSeq = 0;

  List<ChatMessage> get messages => _messages;

  /// 방을 열고 지난 대화를 읽은 뒤 실시간 연결을 붙인다.
  Future<void> open({required bool readOnly}) async {
    isReadOnly = readOnly;
    await loadMessages();

    // 보관된 방은 서버가 구독 자체를 거절한다. 붙으려 들면 오류만 남는다.
    if (isReadOnly) return;
    _listen();
    _realtime.connect(roomId);
  }

  Future<void> loadMessages() async {
    isLoading = true;
    notifyListeners();
    try {
      final loaded = await _chatRepository.getMessages(roomId);
      // 아직 못 보낸 말은 서버 기록에 없다. 그대로 갈아끼우면 화면에서 사라져
      // 사용자는 보낸 것이 없어졌다고 본다. 뒤에 남겨 둔다.
      final unsent = _messages.where((m) =>
          m.pending && _outbox.any((o) => o.clientMsgId == m.clientMsgId));
      _messages = [...loaded, ...unsent];
      final latest = loaded.isEmpty ? 0 : loaded.last.seq;
      if (latest > 0) {
        await _chatRepository.markAsRead(roomId, latest);
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// 아직 서버에 닿지 못한 말. 다시 붙을 때 순서대로 내보낸다.
  ///
  /// 소켓이 죽어도 REST 가 대신 보내 주지만, 소켓이 죽는 상황은 대개 망이 나쁜
  /// 상황이라 REST 도 함께 실패한다. 터널·엘리베이터처럼 여행 중에 흔하다.
  /// 그때 버리면 사용자는 다시 쳐야 하는데, 정작 무엇을 다시 쳐야 하는지는
  /// 화면에서 사라진 뒤다.
  final List<_Outgoing> _outbox = [];

  /// 쌓아 둘 상한. 오래 끊긴 뒤 한꺼번에 밀려 나가면 서버의 전송 한도에 걸리고,
  /// 그 시점엔 사용자도 이미 화면을 떠났을 가능성이 크다.
  static const int _maxOutbox = 20;

  /// 아직 못 보낸 말이 있는지. 화면이 안내를 고를 때 본다.
  bool get hasUnsent => _outbox.isNotEmpty;

  void _listen() {
    _eventSub ??= _realtime.events.listen(_onEvent);
    _stateSub ??= _realtime.states.listen(_onState);
    // 끊긴 동안의 대화는 브로커가 다시 보내 주지 않으므로 직접 메운다.
    _reconnectSub ??= _realtime.reconnected.listen((_) => loadMessages());
  }

  void _onState(ChatConnectionState state) {
    // 붙자마자 보관해 둔 것을 내보낸다. 아래 재연결 알림이 기록을 다시 읽는데,
    // 그 전에 서버에 도착해 있어야 그 목록에 함께 담긴다.
    if (state == ChatConnectionState.connected) {
      _flushOutbox();
    }
    realtimeNotice = switch (state) {
      ChatConnectionState.authRequired => '로그인이 필요해요.',
      ChatConnectionState.disconnected => '연결이 끊어졌어요. 다시 연결 중이에요.',
      _ => null,
    };
    notifyListeners();
  }

  void _onEvent(ChatEvent event) {
    switch (event.kind) {
      case ChatEventKind.message:
      case ChatEventKind.system:
        _onIncoming(event.data);
      case ChatEventKind.read:
        // 누군가 읽었으면 안 읽은 인원수가 줄어 있으므로 다시 맞춘다.
        unawaited(_refreshUnread());
      case ChatEventKind.roomClosed:
        isReadOnly = true;
        realtimeNotice = '여행이 끝나 보관된 채팅방이에요.';
        _realtime.disconnect();
        notifyListeners();
      case ChatEventKind.error:
        _sendError = event.reason ?? '메시지를 보내지 못했어요.';
        notifyListeners();
      case ChatEventKind.typing:
      case ChatEventKind.presence:
      case ChatEventKind.unknown:
        break;
    }
  }

  /// 방송으로 들어온 대화 한 줄을 화면에 넣는다.
  ///
  /// 보낸 사람도 자기 메시지를 방송으로 되받는다. 미리 그려 둔 줄이 있으면
  /// 그것을 이 줄로 갈아 끼워야 같은 말이 두 번 남지 않는다.
  void _onIncoming(Map<String, dynamic>? data) {
    if (data == null) return;
    final repository = _chatRepository;
    if (repository is! ApiChatRepository) return;

    final incoming = repository.fromEvent(ChatMessageResponse.fromJson(data));

    final pendingIndex = incoming.clientMsgId == null
        ? -1
        : _messages.indexWhere((m) => m.pending && m.clientMsgId == incoming.clientMsgId);
    if (pendingIndex >= 0) {
      _messages = [..._messages]..[pendingIndex] = incoming;
    } else if (_messages.any((m) => !m.pending && m.seq == incoming.seq)) {
      // 이미 들고 있는 순번이면 다시 넣지 않는다(재연결 직후 겹칠 수 있다).
      return;
    } else {
      _messages = [..._messages, incoming];
    }
    notifyListeners();

    // 열어 둔 방의 대화는 읽은 것으로 본다.
    unawaited(_chatRepository.markAsRead(roomId, incoming.seq));
  }

  Future<void> _refreshUnread() async {
    try {
      _messages = await _chatRepository.getMessages(roomId);
      notifyListeners();
    } catch (_) {
      // 표시용 숫자라 실패해도 대화 자체에는 영향이 없다.
    }
  }

  /// 전송 실패 안내를 한 번만 꺼내 간다. 꺼내면 지워져서 같은 안내가
  /// 화면 갱신마다 반복해 뜨지 않는다.
  String? consumeSendError() {
    final error = _sendError;
    _sendError = null;
    return error;
  }

  /// 대화를 보낸다.
  ///
  /// 먼저 화면에 그려 두고 보낸다. 소켓이 살아 있으면 그 길로, 아니면 REST 로
  /// 보낸다. 어느 쪽이든 서버가 임시 식별자를 되돌려 주므로 미리 그려 둔 줄과
  /// 짝지어 갈아 끼울 수 있다.
  Future<void> sendMessage(String text) async {
    final clientMsgId = 'c-${AuthStore.instance.userId ?? 0}-${_sendSeq++}-'
        '${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = ChatMessage(
      roomId: roomId,
      seq: 0,
      senderId: AuthStore.instance.userId,
      senderName: '나',
      text: text,
      sentAt: DateTime.now(),
      isMe: true,
      clientMsgId: clientMsgId,
      pending: true,
    );
    _messages = [..._messages, optimistic];
    notifyListeners();

    if (_realtime.isConnected) {
      _realtime.sendMessage(roomId, text, clientMsgId);
      return;
    }

    try {
      final saved = await _chatRepository.sendMessage(roomId, text, clientMsgId);
      _replacePending(clientMsgId, saved);
    } on ApiException catch (e) {
      // 서버가 답을 했다면 그 판단은 다시 보내도 같다 — 참가자가 아니거나,
      // 너무 길거나, 방이 닫혔거나. 사유를 보여 주고 말풍선을 걷는다.
      //
      // 다만 응답 지연은 서버의 판단이 아니라 길이 막힌 것에 가깝다. 그때는
      // 버리지 않고 보관한다.
      if (e.statusCode == 408) {
        _hold(text, clientMsgId);
      } else {
        _dropPending(clientMsgId);
        _sendError = e.message;
        notifyListeners();
      }
    } catch (_) {
      // 서버가 답을 못 한 경우다. 망이 끊겼거나 주소에 닿지 못했다. 다시 붙으면
      // 나갈 수 있으므로 보관한다. 말풍선은 회색으로 남아 아직 안 갔음을 알린다.
      _hold(text, clientMsgId);
    }
  }

  /// 나가지 못한 말을 보관한다. 말풍선은 회색으로 남겨 둔다.
  ///
  /// 넘치면 가장 오래된 것부터 버린다. 최근 것을 버리면 방금 친 말이 사라져
  /// 사용자에게 더 이상하게 보인다.
  void _hold(String text, String clientMsgId) {
    if (_outbox.length >= _maxOutbox) {
      final dropped = _outbox.removeAt(0);
      _dropPending(dropped.clientMsgId);
    }
    _outbox.add(_Outgoing(text, clientMsgId));
    notifyListeners();
  }

  /// 보관해 둔 말을 순서대로 내보낸다.
  ///
  /// 소켓으로만 보낸다. 이 함수가 불리는 시점은 방금 붙은 직후라 REST 로
  /// 되돌아갈 이유가 없다. 도중에 다시 끊기면 남은 것은 그대로 두고 멈춘다 —
  /// 순서가 어긋나면 대화가 뒤섞인다.
  void _flushOutbox() {
    while (_outbox.isNotEmpty && _realtime.isConnected) {
      final held = _outbox.first;
      _realtime.sendMessage(roomId, held.text, held.clientMsgId);
      _outbox.removeAt(0);
    }
  }

  void _replacePending(String clientMsgId, ChatMessage saved) {
    final index = _messages.indexWhere((m) => m.pending && m.clientMsgId == clientMsgId);
    if (index < 0) return;
    _messages = [..._messages]..[index] = saved;
    notifyListeners();
  }

  void _dropPending(String clientMsgId) {
    _messages = _messages
        .where((m) => !(m.pending && m.clientMsgId == clientMsgId))
        .toList();
  }

  /// 초대 링크를 가져온다. 이미 받아 둔 것이 살아 있으면 그것을 그대로 준다.
  Future<InviteLink> getInviteLink() async {
    final cached = _inviteLink;
    final expiry = cached?.expiresAt;
    if (cached != null && (expiry == null || expiry.isAfter(DateTime.now()))) {
      return cached;
    }
    final issued = await _inviteLinkRepository.generateInviteLink(roomId);
    _inviteLink = issued;
    return issued;
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _stateSub?.cancel();
    _reconnectSub?.cancel();
    _realtime.dispose();
    super.dispose();
  }
}

/// 아직 나가지 못한 말 한 건.
class _Outgoing {
  const _Outgoing(this.text, this.clientMsgId);

  final String text;

  /// 서버가 방송에 그대로 실어 돌려주므로, 미리 그려 둔 말풍선과 짝지어
  /// 바꿔치기할 수 있다. 없으면 같은 말이 두 번 남는다.
  final String clientMsgId;
}
