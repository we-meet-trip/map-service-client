import '../local/message_local_store.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../../core/state/trip_repository.dart' show mockCompletedTrip;
import 'chat_repository.dart';

class MockChatRepository implements ChatRepository {
  static final _now = DateTime.now();
  static final _trip = _now.subtract(const Duration(days: 13));

  static final List<ChatRoom> _rooms = [
    ChatRoom(
      id: mockCompletedTrip.id,
      title: '여수 바다 여행',
      participantCount: 3,
      type: ChatRoomType.past,
      hasUnread: false,
      lastMessage: '사진 나중에 공유해줘요!!',
      lastMessageAt: _now.subtract(const Duration(days: 12, hours: 3)),
    ),
  ];

  static final _seedMessages = <String, List<ChatMessage>>{
    mockCompletedTrip.id: [
      ChatMessage(
        id: '${mockCompletedTrip.id}_1',
        roomId: mockCompletedTrip.id,
        senderId: 'user_jiyeon',
        senderName: '지연',
        text: '오동도 너무 예쁘다 진짜',
        sentAt: _trip.subtract(const Duration(hours: 2)),
        isMe: false,
      ),
      ChatMessage(
        id: '${mockCompletedTrip.id}_2',
        roomId: mockCompletedTrip.id,
        senderId: 'me',
        senderName: '나',
        text: '맞아요 바람도 시원하고 최고',
        sentAt: _trip.subtract(const Duration(hours: 1, minutes: 55)),
        isMe: true,
      ),
      ChatMessage(
        id: '${mockCompletedTrip.id}_3',
        roomId: mockCompletedTrip.id,
        senderId: 'user_minsu',
        senderName: '민수',
        text: '케이블카 탈 때 뷰 실화냐고',
        sentAt: _trip.subtract(const Duration(hours: 1, minutes: 30)),
        isMe: false,
      ),
      ChatMessage(
        id: '${mockCompletedTrip.id}_4',
        roomId: mockCompletedTrip.id,
        senderId: 'me',
        senderName: '나',
        text: '향일암 일출 보려면 내일 6시에 출발해야 할 것 같아요',
        sentAt: _trip.subtract(const Duration(hours: 1)),
        isMe: true,
      ),
      ChatMessage(
        id: '${mockCompletedTrip.id}_5',
        roomId: mockCompletedTrip.id,
        senderId: 'user_jiyeon',
        senderName: '지연',
        text: '6시요?? 😭 알겠어요 일찍 자야겠다',
        sentAt: _trip.subtract(const Duration(minutes: 50)),
        isMe: false,
      ),
      ChatMessage(
        id: '${mockCompletedTrip.id}_6',
        roomId: mockCompletedTrip.id,
        senderId: 'user_minsu',
        senderName: '민수',
        text: '수산시장에서 먹은 회 진짜 최고였는데',
        sentAt: _now.subtract(const Duration(days: 12, hours: 5)),
        isMe: false,
      ),
      ChatMessage(
        id: '${mockCompletedTrip.id}_7',
        roomId: mockCompletedTrip.id,
        senderId: 'me',
        senderName: '나',
        text: '거기 또 가고 싶다 진짜로',
        sentAt: _now.subtract(const Duration(days: 12, hours: 4)),
        isMe: true,
      ),
      ChatMessage(
        id: '${mockCompletedTrip.id}_8',
        roomId: mockCompletedTrip.id,
        senderId: 'user_jiyeon',
        senderName: '지연',
        text: '사진 나중에 공유해줘요!!',
        sentAt: _now.subtract(const Duration(days: 12, hours: 3)),
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
      id: tripId,
      title: tripName,
      participantCount: 1,
      type: ChatRoomType.upcoming,
      hasUnread: false,
      lastMessage: '채팅방이 생성되었습니다.',
      lastMessageAt: DateTime.now(),
    );
    _rooms.add(newRoom);
    return newRoom;
  }
}
