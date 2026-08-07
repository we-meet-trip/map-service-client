import 'package:flutter/foundation.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/repositories/invite_link_repository.dart';

class ChatRoomDetailProvider extends ChangeNotifier {
  ChatRoomDetailProvider(this._chatRepository, this._inviteLinkRepository, this.roomId);

  final ChatRepository _chatRepository;
  final InviteLinkRepository _inviteLinkRepository;
  final String roomId;

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
    final optimistic = ChatMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      roomId: roomId,
      senderId: 'me',
      senderName: '나',
      text: text,
      sentAt: DateTime.now(),
      isMe: true,
    );
    _messages = [..._messages, optimistic];
    notifyListeners();
    await _chatRepository.sendMessage(roomId, text);
    await _chatRepository.updateLastMessage(roomId, text, optimistic.sentAt);
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
