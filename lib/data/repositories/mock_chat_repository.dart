import '../local/message_local_store.dart';
import '../models/chat_message.dart';
import '../models/chat_participant.dart';
import '../models/chat_room.dart';
import '../../common/theme/app_colors.dart';
import '../../core/state/trip_repository.dart' show mockCompletedTrip, mockPlannedTrip;
import 'chat_repository.dart';

class MockChatRepository implements ChatRepository {
  static final _now = DateTime.now();

  static final _jisoo = ChatParticipant(
    id: 'user_jisoo',
    name: '지수',
    avatarColor: AppColors.avatarColors[1],
  );
  static final _hyunwoo = ChatParticipant(
    id: 'user_hyunwoo',
    name: '현우',
    avatarColor: AppColors.avatarColors[3],
  );
  static final _jiyeon = ChatParticipant(
    id: 'user_jiyeon',
    name: '지연',
    avatarColor: AppColors.avatarColors[5],
  );

  static final List<ChatRoom> _seedRooms = [
    ChatRoom(
      id: mockPlannedTrip.id,
      title: '성수동 나들이',
      participants: [_jisoo, _hyunwoo],
      participantCount: 3,
      type: ChatRoomType.upcoming,
      hasUnread: true,
      lastMessage: _seedMessages[mockPlannedTrip.id]!.last.text,
      lastMessageAt: _seedMessages[mockPlannedTrip.id]!.last.sentAt,
    ),
    ChatRoom(
      id: mockCompletedTrip.id,
      title: '여수 바다 여행',
      participants: [_jiyeon],
      participantCount: 2,
      type: ChatRoomType.past,
      hasUnread: false,
      lastMessage: _seedMessages[mockCompletedTrip.id]!.last.text,
      lastMessageAt: _seedMessages[mockCompletedTrip.id]!.last.sentAt,
    ),
  ];

  static final List<ChatRoom> _dynamicRooms = [];

  static List<ChatRoom> get _rooms => [..._seedRooms, ..._dynamicRooms];

  static final _seedMessages = <String, List<ChatMessage>>{
    mockPlannedTrip.id: [
      ChatMessage(
        id: '${mockPlannedTrip.id}_1',
        roomId: mockPlannedTrip.id,
        senderId: 'user_jisoo',
        senderName: '지수',
        text: '성수 가는 날 확정됐나요?',
        sentAt: _now.subtract(const Duration(hours: 5)),
        isMe: false,
      ),
      ChatMessage(
        id: '${mockPlannedTrip.id}_2',
        roomId: mockPlannedTrip.id,
        senderId: 'me',
        senderName: '나',
        text: '네 다음 주 토요일로 확정이에요!',
        sentAt: _now.subtract(const Duration(hours: 4, minutes: 50)),
        isMe: true,
      ),
      ChatMessage(
        id: '${mockPlannedTrip.id}_3',
        roomId: mockPlannedTrip.id,
        senderId: 'user_hyunwoo',
        senderName: '현우',
        text: '안녕하세요~~',
        sentAt: _now.subtract(const Duration(hours: 4, minutes: 30)),
        isMe: false,
      ),
      ChatMessage(
        id: '${mockPlannedTrip.id}_4',
        roomId: mockPlannedTrip.id,
        senderId: 'me',
        senderName: '나',
        text: '환영합니다 🎉🎉',
        sentAt: _now.subtract(const Duration(hours: 4)),
        isMe: true,
      ),
      ChatMessage(
        id: '${mockPlannedTrip.id}_5',
        roomId: mockPlannedTrip.id,
        senderId: 'user_jisoo',
        senderName: '지수',
        text: '카페를 먼저 갈까요?',
        sentAt: _now.subtract(const Duration(hours: 2)),
        isMe: false,
      ),
    ],
    mockCompletedTrip.id: [
      ChatMessage(
        id: '${mockCompletedTrip.id}_1',
        roomId: mockCompletedTrip.id,
        senderId: 'me',
        senderName: '나',
        text: '여수 너무 좋았다',
        sentAt: _now.subtract(const Duration(days: 12, hours: 5)),
        isMe: true,
      ),
      ChatMessage(
        id: '${mockCompletedTrip.id}_2',
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
    _updateRoom(roomId, (r) => r.copyWith(lastMessage: text, lastMessageAt: sentAt));
  }

  @override
  Future<void> markAsRead(String roomId) async {
    _updateRoom(roomId, (r) => r.copyWith(hasUnread: false));
  }

  static void _updateRoom(String roomId, ChatRoom Function(ChatRoom) update) {
    final seedIndex = _seedRooms.indexWhere((r) => r.id == roomId);
    if (seedIndex != -1) {
      _seedRooms[seedIndex] = update(_seedRooms[seedIndex]);
      return;
    }
    final dynIndex = _dynamicRooms.indexWhere((r) => r.id == roomId);
    if (dynIndex != -1) {
      _dynamicRooms[dynIndex] = update(_dynamicRooms[dynIndex]);
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
    _dynamicRooms.add(newRoom);
    return newRoom;
  }
}
