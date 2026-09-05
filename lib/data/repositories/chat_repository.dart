import '../models/chat_message.dart';
import '../models/chat_room.dart';

/// 채팅 데이터 출입구.
abstract class ChatRepository {
  /// 내가 들어가 있는 방 목록.
  Future<List<ChatRoom>> getChatRooms();

  /// 방 하나를 번호로 가져온다. 링크로 들어왔을 때처럼 목록을 거치지 않는 길에 쓴다.
  Future<ChatRoom> getRoom(int roomId);

  /// 지난 대화. [beforeSeq] 를 주면 그 순번보다 앞을 읽는다.
  Future<List<ChatMessage>> getMessages(int roomId, {int? beforeSeq});

  /// 대화를 보낸다. [clientMsgId] 는 돌아온 것과 짝지을 임시 식별자다.
  Future<ChatMessage> sendMessage(int roomId, String text, String clientMsgId);

  /// 일정에 딸린 방을 만들거나 이미 있으면 그것을 가져온다.
  ///
  /// 제목은 서버가 일정에서 가져다 붙이므로 여기서 넘기지 않는다.
  Future<ChatRoom> createChatRoomForSchedule(int scheduleId);

  /// 읽음 위치를 [lastReadSeq] 까지 올린다.
  Future<void> markAsRead(int roomId, int lastReadSeq);

  /// 방의 참가자들. 보낸 사람 이름을 붙이는 데 쓴다.
  Future<List<ChatUser>> getParticipants(int roomId);

  /// 방에서 나간다. 방장이 나가면 서버가 방을 종료한다.
  Future<void> leave(int roomId);

  /// 참가자를 내보낸다. 방장 여부의 최종 판정은 서버가 한다.
  Future<void> kick(int roomId, int userId);
}

/// 참가자 한 명의 표시 정보.
class ChatUser {
  const ChatUser({
    required this.userId,
    required this.nickname,
    required this.isOwner,
    required this.isActive,
  });

  final int userId;
  final String nickname;
  final bool isOwner;

  /// 아직 방에 남아 있는지. 나갔거나 내보내진 사람은 거짓이다.
  final bool isActive;
}
