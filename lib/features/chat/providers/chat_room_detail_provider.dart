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
