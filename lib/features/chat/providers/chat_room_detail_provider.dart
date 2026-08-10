import 'dart:async';

import 'package:flutter/foundation.dart';

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
      _messages = loaded;
      final latest = loaded.isEmpty ? 0 : loaded.last.seq;
      if (latest > 0) {
        await _chatRepository.markAsRead(roomId, latest);
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _listen() {
    _eventSub ??= _realtime.events.listen(_onEvent);
    _stateSub ??= _realtime.states.listen(_onState);
    // 끊긴 동안의 대화는 브로커가 다시 보내 주지 않으므로 직접 메운다.
    _reconnectSub ??= _realtime.reconnected.listen((_) => loadMessages());
  }

  void _onState(ChatConnectionState state) {
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
    } catch (e) {
      _dropPending(clientMsgId);
      _sendError = '메시지를 보내지 못했어요.';
      notifyListeners();
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
