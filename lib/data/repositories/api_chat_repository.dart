import '../../core/api/chat_api_service.dart';
import '../../core/state/auth_store.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import 'chat_repository.dart';

/// 서버를 실제로 보는 채팅 저장소.
///
/// 서버는 메시지에 보낸 사람의 번호만 싣고 이름은 싣지 않는다. 이름은 참가자
/// 목록에서 찾아 붙이는데, 나갔거나 내보내진 사람은 그 목록에 없으므로 그때는
/// 대체 문구를 쓴다. 이름을 못 찾았다고 대화 줄 자체를 빠뜨리면 대화의 흐름이
/// 끊긴 것처럼 보인다.
class ApiChatRepository implements ChatRepository {
  ApiChatRepository({ChatApiService? api}) : _api = api ?? ChatApiService.instance;

  final ChatApiService _api;

  /// 방별 참가자 이름 표. 대화를 읽을 때마다 다시 묻지 않으려고 들고 있는다.
  final Map<int, Map<int, String>> _nameCache = {};

  static const _unknownSender = '알 수 없음';

  @override
  Future<List<ChatRoom>> getChatRooms() async {
    final rows = await _api.listRooms();
    return rows
        .map((r) => ChatRoom(
              id: r.roomId,
              scheduleId: r.scheduleId,
              title: r.title,
              participantCount: r.participantCount,
              readOnly: r.readOnly,
              latestSeq: r.latestSeq,
              unreadCount: r.unreadCount,
              lastMessage: r.lastMessage ?? '',
              lastMessageAt: r.lastMessageAt,
            ))
        .toList();
  }

  @override
  Future<ChatRoom> getRoom(int roomId) async {
    final room = await _api.getRoom(roomId);
    return _toRoom(room);
  }

  @override
  Future<ChatRoom> createChatRoomForSchedule(int scheduleId) async {
    final room = await _api.createOrGetRoom(scheduleId);
    return _toRoom(room);
  }

  @override
  Future<List<ChatMessage>> getMessages(int roomId, {int? beforeSeq}) async {
    final names = await _names(roomId);
    final history = await _api.history(roomId, beforeSeq: beforeSeq);
    // 서버는 최신부터 내려 주고 화면은 위에서 아래로 읽으므로 뒤집는다.
    return history.messages.reversed.map((m) => _toMessage(m, names)).toList();
  }

  @override
  Future<ChatMessage> sendMessage(int roomId, String text, String clientMsgId) async {
    final names = await _names(roomId);
    final sent = await _api.send(roomId, text, clientMsgId);
    return _toMessage(sent, names);
  }

  @override
  Future<void> markAsRead(int roomId, int lastReadSeq) =>
      _api.markRead(roomId, lastReadSeq);

  @override
  Future<List<ChatUser>> getParticipants(int roomId) async {
    final rows = await _api.participants(roomId);
    _nameCache[roomId] = {
      for (final p in rows) p.userId: p.nickname ?? _unknownSender,
    };
    return rows
        .map((p) => ChatUser(
              userId: p.userId,
              nickname: p.nickname ?? _unknownSender,
              isOwner: p.role == 'OWNER',
              isActive: p.status == 'ACTIVE',
            ))
        .toList();
  }

  ChatRoom _toRoom(ChatRoomResponse r) => ChatRoom(
        id: r.roomId,
        scheduleId: r.scheduleId,
        title: r.title,
        participantCount: r.participantCount,
        readOnly: r.readOnly,
        expiresAt: r.expiresAt,
        latestSeq: r.latestSeq,
      );

  /// 방의 이름 표. 없으면 한 번 받아 둔다.
  Future<Map<int, String>> _names(int roomId) async {
    final cached = _nameCache[roomId];
    if (cached != null) return cached;
    await getParticipants(roomId);
    return _nameCache[roomId] ?? const {};
  }

  ChatMessage _toMessage(ChatMessageResponse m, Map<int, String> names) {
    final me = AuthStore.instance.userId;
    final isSystem = m.type == 'SYSTEM';
    return ChatMessage(
      roomId: m.roomId,
      seq: m.seq,
      senderId: m.senderId,
      senderName: isSystem ? '' : (names[m.senderId] ?? _unknownSender),
      text: m.content ?? '',
      sentAt: m.createdAt ?? DateTime.now(),
      isMe: m.senderId != null && me != null && m.senderId == me,
      type: isSystem ? ChatMessageType.system : ChatMessageType.text,
      systemPayload: m.systemPayload,
      unreadCount: m.unreadCount,
      clientMsgId: m.clientMsgId,
    );
  }

  /// 방 방송으로 들어온 메시지를 화면 모델로 바꾼다.
  ///
  /// 실시간 경로는 이름 표를 새로 받을 겨를이 없으므로 이미 받아 둔 것을 쓴다.
  ChatMessage fromEvent(ChatMessageResponse m) =>
      _toMessage(m, _nameCache[m.roomId] ?? const {});
}
