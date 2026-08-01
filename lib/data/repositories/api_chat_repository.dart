import '../../core/api/api_client.dart';
import '../../core/state/auth_store.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import 'chat_repository.dart';

/// 서버의 대화방 API 를 쓰는 저장소.
///
/// 대화방 경로는 인가 시행 설정과 무관하게 **항상 토큰을 요구**한다. 공통
/// HTTP 계층이 토큰을 붙이고 만료를 갱신하므로 여기서는 형태만 옮긴다.
///
/// 서버가 방을 보관 상태로 돌리면(`read_only`) 메시지를 보낼 수 없고 실시간
/// 구독도 거부된다. 이력 조회는 그대로 되므로 지난 방으로 분류해 보여 준다.
class ApiChatRepository implements ChatRepository {
  ApiChatRepository();

  final _api = ApiClient.instance;

  @override
  Future<List<ChatRoom>> getChatRooms() async {
    final json = await _api.get('/api/v1/chat/rooms');
    final rooms = json['data'];
    if (rooms is! List) return const [];
    return rooms.whereType<Map<String, dynamic>>().map(_toRoom).toList();
  }

  /// 이력은 최신순으로 온다. 화면은 오래된 것부터 그리므로 뒤집어 넘긴다.
  ///
  /// 시스템 메시지(입장·강퇴·일정 안내)는 보낸 사람이 없다. 말풍선이 보낸
  /// 사람을 요구하므로 안내 표기를 대신 채운다.
  @override
  Future<List<ChatMessage>> getMessages(String roomId) async {
    final json = await _api.get('/api/v1/chat/rooms/$roomId/messages');
    final messages = json['messages'];
    if (messages is! List) return const [];
    final myId = AuthStore.instance.userId;
    return messages
        .whereType<Map<String, dynamic>>()
        .map((m) => _toMessage(roomId, m, myId))
        .toList()
        .reversed
        .toList();
  }

  @override
  Future<void> sendMessage(String roomId, String text) async {
    await _api.post('/api/v1/chat/rooms/$roomId/messages', body: {
      'content': text,
    });
  }

  /// 저장된 일정으로 대화방을 만든다(이미 있으면 그 방이 온다).
  ///
  /// 일정 하나에 방 하나이고, **자기가 저장한 일정에만** 만들 수 있다.
  Future<String> createRoom(int scheduleId) async {
    final json = await _api.post('/api/v1/chat/rooms', body: {
      'schedule_id': scheduleId,
    });
    return '${json['room_id']}';
  }

  /// 여기까지 읽었다고 알린다. 서버가 다른 참가자에게도 알려 준다.
  Future<void> markRead(String roomId, int lastReadSeq) async {
    await _api.post('/api/v1/chat/rooms/$roomId/read', body: {
      'last_read_seq': lastReadSeq,
    });
  }

  ChatRoom _toRoom(Map<String, dynamic> json) {
    final readOnly = json['read_only'] == true;
    return ChatRoom(
      id: '${json['room_id']}',
      title: json['title'] as String? ?? '여행 대화방',
      participantCount: 1,
      // 보관으로 넘어간 방은 지난 여행으로 본다.
      type: readOnly ? ChatRoomType.past : ChatRoomType.upcoming,
      hasUnread: (json['unread_count'] as num? ?? 0) > 0,
      lastMessage: json['last_message'] as String? ?? '',
      // 목록 응답에는 마지막 시각이 없다. 목록 화면이 이 값을 그리지 않으므로
      // 자리만 채운다.
      lastMessageAt: DateTime.now(),
      linkedTripId: json['schedule_id'] == null
          ? null
          : '${json['schedule_id']}',
    );
  }

  ChatMessage _toMessage(
      String roomId, Map<String, dynamic> json, int? myId) {
    final senderId = json['sender_id'] as int?;
    final isSystem = json['type'] == 'SYSTEM';
    return ChatMessage(
      id: '${json['seq']}',
      roomId: roomId,
      senderId: senderId?.toString() ?? 'system',
      senderName: isSystem ? '안내' : '${senderId ?? ''}',
      text: json['content'] as String? ?? '',
      sentAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      isMe: senderId != null && myId != null && senderId == myId,
    );
  }
}
