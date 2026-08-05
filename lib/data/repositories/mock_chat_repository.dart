import '../local/message_local_store.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import 'chat_repository.dart';

class MockChatRepository implements ChatRepository {
  static final _now = DateTime.now();
  static final _yesterday = _now.subtract(const Duration(days: 1));

  static final List<ChatRoom> _rooms = [
    ChatRoom(
      id: '1',
      title: '속초 당일치기',
      participantCount: 3,
      type: ChatRoomType.upcoming,
      hasUnread: false,
      lastMessage: '식당 예약했습니다~',
      lastMessageAt: DateTime(_yesterday.year, _yesterday.month, _yesterday.day, 14, 32),
      linkedTripId: 'trip_001',
    ),
    ChatRoom(
      id: '2',
      title: '강릉 바다 여행',
      participantCount: 2,
      type: ChatRoomType.upcoming,
      hasUnread: true,
      lastMessage: '내일 8시에 역 앞에서 봐요!',
      lastMessageAt: DateTime(_now.year, _now.month, _now.day, 9, 15),
    ),
    ChatRoom(
      id: '3',
      title: '춘천 닭갈비 투어',
      participantCount: 4,
      type: ChatRoomType.past,
      hasUnread: false,
      lastMessage: '사진 너무 예쁘네요! 다들 너무 고생하...',
      lastMessageAt: DateTime(_now.year, 7, 11, 20, 0),
    ),
    ChatRoom(
      id: '4',
      title: '춘천 1박2일',
      participantCount: 3,
      type: ChatRoomType.past,
      hasUnread: false,
      lastMessage: '사진 너무 예쁘네요! 다들 너무 고생하...',
      lastMessageAt: DateTime(_now.year, 6, 28, 17, 0),
    ),
  ];

  // 최초 실행 시 Hive에 시드할 목 메시지
  static final _seedMessages = <String, List<ChatMessage>>{
    '1': [
      ChatMessage(
        id: 'm1',
        roomId: '1',
        senderId: 'user_junho',
        senderName: '준호',
        text: '속초 드디어 가는군요!!!',
        sentAt: DateTime(_yesterday.year, _yesterday.month, _yesterday.day, 10, 0),
        isMe: false,
      ),
      ChatMessage(
        id: 'm2',
        roomId: '1',
        senderId: 'me',
        senderName: '나',
        text: '바다가 진짜 예쁠 거예요',
        sentAt: DateTime(_yesterday.year, _yesterday.month, _yesterday.day, 10, 5),
        isMe: true,
      ),
      ChatMessage(
        id: 'm3',
        roomId: '1',
        senderId: 'user_minjae',
        senderName: '민재',
        text: '식당 예약했습니다~',
        sentAt: DateTime(_yesterday.year, _yesterday.month, _yesterday.day, 14, 32),
        isMe: false,
      ),
    ],
    '2': [
      ChatMessage(
        id: 'm2_1',
        roomId: '2',
        senderId: 'user_soyeon',
        senderName: '소연',
        text: '강릉 숙소 예약 완료했어요!',
        sentAt: DateTime(_now.year, _now.month, _now.day, 8, 40),
        isMe: false,
      ),
      ChatMessage(
        id: 'm2_2',
        roomId: '2',
        senderId: 'me',
        senderName: '나',
        text: '오 진짜요? 어디로 잡았어요?',
        sentAt: DateTime(_now.year, _now.month, _now.day, 8, 52),
        isMe: true,
      ),
      ChatMessage(
        id: 'm2_3',
        roomId: '2',
        senderId: 'user_soyeon',
        senderName: '소연',
        text: '내일 8시에 역 앞에서 봐요!',
        sentAt: DateTime(_now.year, _now.month, _now.day, 9, 15),
        isMe: false,
      ),
    ],
  };

  final _store = MessageLocalStore.instance;

  @override
  Future<List<ChatRoom>> getChatRooms() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _rooms;
  }

  @override
  Future<List<ChatMessage>> getMessages(String roomId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!_store.hasMessages(roomId)) {
      final seed = _seedMessages[roomId] ?? [];
      if (seed.isNotEmpty) await _store.saveMessages(seed);
    }
    return _store.getMessages(roomId);
  }

  @override
  Future<void> sendMessage(String roomId, String text) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final msg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      roomId: roomId,
      senderId: 'me',
      senderName: '나',
      text: text,
      sentAt: DateTime.now(),
      isMe: true,
    );
    await _store.saveMessage(msg);
  }

  @override
  Future<void> updateLastMessage(String roomId, String text, DateTime sentAt) async {
    final index = _rooms.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      _rooms[index] = _rooms[index].copyWith(lastMessage: text, lastMessageAt: sentAt);
    }
  }

  @override
  Future<void> markAsRead(String roomId) async {
    final index = _rooms.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      _rooms[index] = _rooms[index].copyWith(hasUnread: false);
    }
  }

  @override
  Future<ChatRoom> createChatRoomForTrip(String tripId, String tripName) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final newRoom = ChatRoom(
      id: 'room_${DateTime.now().millisecondsSinceEpoch}',
      title: tripName,
      participantCount: 1,
      type: ChatRoomType.upcoming,
      hasUnread: false,
      lastMessage: '채팅방이 생성되었습니다.',
      lastMessageAt: DateTime.now(),
      linkedTripId: tripId,
    );
    _rooms.add(newRoom);
    return newRoom;
  }
}
