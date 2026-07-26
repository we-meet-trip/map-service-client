import 'package:flutter/foundation.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/repositories/chat_repository.dart';

class ChatRoomDetailProvider extends ChangeNotifier {
  ChatRoomDetailProvider(this._repository, this.roomId);

  final ChatRepository _repository;
  final String roomId;

  List<ChatMessage> _messages = [];
  bool isLoading = false;

  List<ChatMessage> get messages => _messages;

  Future<void> loadMessages() async {
    isLoading = true;
    notifyListeners();
    try {
      _messages = await _repository.getMessages(roomId);
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
    await _repository.sendMessage(roomId, text);
  }
}
