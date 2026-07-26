import '../models/chat_room.dart';
import '../models/chat_message.dart';

abstract class ChatRepository {
  Future<List<ChatRoom>> getChatRooms();
  Future<List<ChatMessage>> getMessages(String roomId);
  Future<void> sendMessage(String roomId, String text);
}
