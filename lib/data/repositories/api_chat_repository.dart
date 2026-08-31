import '../../core/api/chat_api_service.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../models/user.dart';
import 'chat_repository.dart';

/// 서버와 실제로 주고받는 채팅 저장소.
///
/// 서버가 주는 것과 화면이 쓰는 것이 한 군데씩 어긋나 있어 여기서 맞춘다.
/// - 방 식별자를 화면은 문자열로, 서버는 숫자로 쓴다.
/// - 실시간 사건과 기록에는 보낸 사람 번호만 실려 오고 이름은 없다. 참가자
///   목록을 방마다 한 번 받아 번호를 이름으로 바꾼다. 이름을 못 찾으면 번호를
///   그대로 보여 준다 — 빈 이름으로 두면 누가 말했는지 사라진다.
class ApiChatRepository implements ChatRepository {
  ApiChatRepository({ChatApiService? api})
      : _api = api ?? ChatApiService.instance;

  final ChatApiService _api;

  /// 방마다의 참가자 이름. 방을 열 때 한 번 받아 두고 계속 쓴다.
  final Map<int, Map<int, String>> _names = {};

  @override
  Future<List<ChatRoom>> getChatRooms() async {
    final rows = await _api.listRooms();
    return rows.map(_toRoom).toList();
  }

  @override
  Future<List<ChatMessage>> getMessages(String roomId) async {
    final id = _idOf(roomId);
    final names = await _namesOf(id);
    final body = await _api.history(id);
    final rows = (body['messages'] as List?) ?? const [];
    final me = _api.myUserId;
    return rows
        .cast<Map<String, dynamic>>()
        .map((row) => toMessage(row, roomId, names, me))
        .toList()
        .reversed
        .toList();
  }

  @override
  Future<void> sendMessage(String roomId, String text, {String? clientMsgId}) async {
    // 소켓이 살아 있을 때는 화면 쪽에서 소켓으로 보낸다. 이 경로는 소켓이
    // 끊겼을 때의 되돌아갈 길이라, 같은 결과를 남기도록 서버가 맞춰 준다.
    await _api.send(_idOf(roomId), text,
        clientMsgId ?? DateTime.now().microsecondsSinceEpoch.toString());
  }

  @override
  Future<ChatRoom> createChatRoomForTrip(String tripId, String tripName) async {
    final scheduleId = int.tryParse(tripId);
    if (scheduleId == null) {
      throw ArgumentError('일정 식별자가 숫자가 아니다: $tripId');
    }
    final room = await _api.createRoom(scheduleId);
    return _toRoom({...room, 'title': room['title'] ?? tripName});
  }

  @override
  Future<void> markAsRead(String roomId) async {
    final id = _idOf(roomId);
    final body = await _api.history(id, limit: 1);
    final rows = (body['messages'] as List?) ?? const [];
    if (rows.isEmpty) {
      return;
    }
    final latest = (rows.first as Map<String, dynamic>)['seq'] as num?;
    if (latest != null) {
      await _api.markRead(id, latest.toInt());
    }
  }

  @override
  Future<void> updateLastMessage(String roomId, String text, DateTime sentAt) async {
    // 마지막 말은 서버가 방 목록에 실어 준다. 앱이 따로 들고 있을 것이 없다.
  }

  /// 실시간 사건 하나를 화면이 쓰는 말로 바꾼다. 이름은 이미 받아 둔 것을 쓴다.
  ChatMessage? messageFromEvent(String roomId, Map<String, dynamic> data) {
    if (data['seq'] == null) {
      return null;
    }
    final id = _idOf(roomId);
    return toMessage(data, roomId, _names[id] ?? const {}, _api.myUserId);
  }

  /// 방의 참가자 이름을 받아 둔다. 이미 받아 둔 방이면 그대로 쓴다.
  Future<Map<int, String>> _namesOf(int roomId) async {
    final cached = _names[roomId];
    if (cached != null) {
      return cached;
    }
    final rows = await _api.participants(roomId);
    final map = {
      for (final row in rows)
        (row['user_id'] as num).toInt(): (row['nickname'] as String?) ?? '',
    };
    _names[roomId] = map;
    return map;
  }

  static int _idOf(String roomId) =>
      int.tryParse(roomId) ?? (throw ArgumentError('방 식별자가 숫자가 아니다: $roomId'));

  ChatRoom _toRoom(Map<String, dynamic> row) {
    final id = (row['room_id'] as num).toInt();
    final readOnly = row['read_only'] as bool? ?? false;
    final lastAt = row['last_message_at'] as String?;
    return ChatRoom(
      id: '$id',
      title: (row['title'] as String?) ?? '여행',
      participants: const <User>[],
      participantCount: (row['participant_count'] as num?)?.toInt() ?? 1,
      // 보관으로 넘어간 방은 지난 여행 칸에 둔다. 서버가 여행 종료일과
      // 유예 기간으로 판정해 내려 주므로 앱이 날짜를 다시 세지 않는다.
      type: readOnly ? ChatRoomType.past : ChatRoomType.upcoming,
      hasUnread: ((row['unread_count'] as num?)?.toInt() ?? 0) > 0,
      lastMessage: (row['last_message'] as String?) ?? '',
      lastMessageAt:
          lastAt == null ? DateTime.now() : DateTime.parse(lastAt).toLocal(),
    );
  }

  /// 서버가 준 말 한 줄을 화면이 쓰는 모양으로 바꾼다.
  static ChatMessage toMessage(
    Map<String, dynamic> row,
    String roomId,
    Map<int, String> names,
    int? myUserId,
  ) {
    final senderId = (row['sender_id'] as num?)?.toInt();
    final isSystem = row['type'] == 'SYSTEM';
    return ChatMessage(
      id: '$roomId-${row['seq']}',
      roomId: roomId,
      senderId: senderId?.toString() ?? 'system',
      senderName: isSystem
          ? '안내'
          : (names[senderId] ?? '').isNotEmpty
              ? names[senderId]!
              : '${senderId ?? ''}',
      text: (row['content'] as String?) ?? '',
      sentAt: DateTime.parse(row['created_at'] as String).toLocal(),
      // 보낸 사람이 없는 안내 말은 누구의 말도 아니다.
      isMe: senderId != null && myUserId != null && senderId == myUserId,
    );
  }
}
