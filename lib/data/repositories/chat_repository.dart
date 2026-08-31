import '../models/chat_room.dart';
import '../models/chat_message.dart';

abstract class ChatRepository {
  Future<List<ChatRoom>> getChatRooms();
  Future<List<ChatMessage>> getMessages(String roomId);
  /// clientMsgId 는 미리 그려 둔 말풍선과 서버가 되돌려 준 방송을 짝짓는
  /// 표식이다. 보낸 사람도 자기 말을 방 방송으로 되받으므로, 이것이 없으면
  /// 같은 말이 화면에 두 번 남는다.
  Future<void> sendMessage(String roomId, String text, {String? clientMsgId});
  Future<ChatRoom> createChatRoomForTrip(String tripId, String tripName);
  Future<void> markAsRead(String roomId);
  Future<void> updateLastMessage(String roomId, String text, DateTime sentAt);
}
