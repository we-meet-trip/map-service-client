import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../../core/api/chat_realtime_service.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/repositories/api_chat_repository.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/repositories/invite_link_repository.dart';

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
  final String roomId;

  StreamSubscription<ChatEvent>? _events;

  List<ChatMessage> _messages = [];
  bool isLoading = false;

  /// 실시간 연결이 거절되었거나 끊어진 사유. 화면이 안내에 쓴다.
  String? realtimeNotice;

  /// 서버가 전송을 거절한 사유. 화면이 한 번 보여주고 지우는 값이라
  /// 읽는 쪽에서 consumeSendError 로 가져간다.
  String? _sendError;

  /// 보관 상태로 넘어간 방. 입력창을 닫아야 한다.
  bool isReadOnly = false;

  String? _inviteLink;
  DateTime? _inviteLinkExpiresAt;

  List<ChatMessage> get messages => _messages;

  /// 기록을 읽고 실시간 연결을 연다. 화면이 열릴 때 한 번 부른다.
  Future<void> start() async {
    await loadMessages();
    _events ??= _realtime.events.listen(_onEvent);
    final id = int.tryParse(roomId);
    if (id != null) {
      await _realtime.connect(id);
    }
  }

  void _onEvent(ChatEvent event) {
    switch (event.kind) {
      case ChatEventKind.message:
      case ChatEventKind.system:
        final data = event.data;
        if (data != null) {
          _onIncoming(data);
        }
      case ChatEventKind.roomClosed:
        isReadOnly = true;
        notifyListeners();
      case ChatEventKind.reconnected:
        // 끊긴 동안 오간 말은 브로커가 다시 주지 않는다. 기록을 다시 읽어야
        // 그 구간이 화면에서 비지 않는다.
        loadMessages();
      case ChatEventKind.error:
        // 거절된 전송을 사용자에게 알린다. 알리지 않으면 보낸 것처럼 남은
        // 말풍선만 화면에 남아, 상대가 못 받은 사실을 끝내 모른다.
        _sendError = event.reason ?? '메시지를 보내지 못했어요.';
        realtimeNotice = _sendError;
        notifyListeners();
      default:
        // 모르는 종류는 흘려보낸다. 서버가 새 사건을 더해도 앱이 죽지 않아야 한다.
        break;
    }
  }

  void _onIncoming(Map<String, dynamic> data) {
    final repository = _chatRepository;
    if (repository is! ApiChatRepository) {
      return;
    }
    final message = repository.messageFromEvent(roomId, data);
    if (message == null) {
      return;
    }
    final echo = data['client_msg_id'] as String?;
    // 보낸 사람도 자기 말을 방 방송으로 되받는다. 미리 그려 둔 말풍선을
    // 표식으로 찾아 바꿔 주지 않으면 같은 말이 두 번 남는다.
    final at = echo == null ? -1 : _messages.indexWhere((m) => m.id == echo);
    if (at >= 0) {
      _messages = [..._messages]..[at] = message;
    } else if (!_messages.any((m) => m.id == message.id)) {
      _messages = [..._messages, message];
    } else {
      return;
    }
    notifyListeners();
  }

  Future<void> loadMessages() async {
    isLoading = true;
    notifyListeners();
    try {
      await _chatRepository.markAsRead(roomId);
      _messages = await _chatRepository.getMessages(roomId);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// 전송 실패 안내를 한 번만 꺼내 간다. 꺼내면 지워져서 같은 안내가
  /// 화면 갱신마다 반복해 뜨지 않는다.
  String? consumeSendError() {
    final error = _sendError;
    _sendError = null;
    return error;
  }


  Future<void> sendMessage(String text) async {
    final clientMsgId = 'c_${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = ChatMessage(
      id: clientMsgId,
      roomId: roomId,
      senderId: 'me',
      senderName: '나',
      text: text,
      sentAt: DateTime.now(),
      isMe: true,
    );
    _messages = [..._messages, optimistic];
    notifyListeners();
    // 소켓이 살아 있으면 그쪽이 빠르다. 반쯤 죽은 소켓을 살아 있다고 세면
    // 보낸 말이 조용히 사라지므로, 판정은 최근에 무언가 받았는지로 한다.
    if (!_realtime.send(text, clientMsgId)) {
      await _chatRepository.sendMessage(roomId, text, clientMsgId: clientMsgId);
    }
    await _chatRepository.updateLastMessage(roomId, text, optimistic.sentAt);
  }

  @override
  void dispose() {
    _events?.cancel();
    _realtime.disconnect();
    super.dispose();
  }

  Future<String> getInviteLink(String roomTitle) async {
    final now = DateTime.now();
    if (_inviteLink != null && _inviteLinkExpiresAt!.isAfter(now)) {
      return _inviteLink!;
    }
    _inviteLink = await _inviteLinkRepository.generateInviteLink(roomId, roomTitle);
    _inviteLinkExpiresAt = now.add(const Duration(days: 7));
    return _inviteLink!;
  }
}
