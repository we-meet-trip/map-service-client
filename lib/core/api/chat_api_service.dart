import 'api_client.dart';

/// 서버가 주는 시각 문자열을 기기 시간대로 바꾼다. 못 읽으면 비운다.
DateTime? _time(dynamic value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;

int _int(dynamic value) => (value as num?)?.toInt() ?? 0;

/// 채팅방 한 개의 전체 정보.
class ChatRoomResponse {
  final int roomId;
  final int? scheduleId;
  final int? ownerId;
  final String title;

  /// 보관 전용으로 넘어갔는지. 참이면 더 이상 말할 수 없다.
  final bool readOnly;

  /// 방이 닫히는 시각.
  final DateTime? expiresAt;

  final int participantCount;

  /// 방의 최신 메시지 순번. 안 읽은 개수를 세는 기준점이다.
  final int latestSeq;

  const ChatRoomResponse({
    required this.roomId,
    required this.scheduleId,
    required this.ownerId,
    required this.title,
    required this.readOnly,
    required this.expiresAt,
    required this.participantCount,
    required this.latestSeq,
  });

  factory ChatRoomResponse.fromJson(Map<String, dynamic> json) =>
      ChatRoomResponse(
        roomId: _int(json['room_id']),
        scheduleId: (json['schedule_id'] as num?)?.toInt(),
        ownerId: (json['owner_id'] as num?)?.toInt(),
        title: json['title'] as String? ?? '',
        readOnly: json['read_only'] as bool? ?? false,
        expiresAt: _time(json['expires_at']),
        participantCount: _int(json['participant_count']),
        latestSeq: _int(json['latest_seq']),
      );
}

/// 목록 화면 한 줄에 필요한 요약.
class ChatRoomSummary {
  final int roomId;
  final int? scheduleId;
  final String title;
  final bool readOnly;
  final int unreadCount;
  final String? lastMessage;

  /// 마지막 대화 시각. 아직 아무도 말하지 않은 방은 비어 있다.
  final DateTime? lastMessageAt;

  final int latestSeq;
  final int participantCount;

  const ChatRoomSummary({
    required this.roomId,
    required this.scheduleId,
    required this.title,
    required this.readOnly,
    required this.unreadCount,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.latestSeq,
    required this.participantCount,
  });

  factory ChatRoomSummary.fromJson(Map<String, dynamic> json) =>
      ChatRoomSummary(
        roomId: _int(json['room_id']),
        scheduleId: (json['schedule_id'] as num?)?.toInt(),
        title: json['title'] as String? ?? '',
        readOnly: json['read_only'] as bool? ?? false,
        unreadCount: _int(json['unread_count']),
        lastMessage: json['last_message'] as String?,
        lastMessageAt: _time(json['last_message_at']),
        latestSeq: _int(json['latest_seq']),
        // 서버가 아직 인원수를 싣지 않는 판이면 최소 나 하나는 있다.
        participantCount: json['participant_count'] == null
            ? 1
            : _int(json['participant_count']),
      );
}

/// 메시지 한 건.
class ChatMessageResponse {
  final int roomId;
  final int seq;

  /// 보낸 사람. 시스템 메시지는 비어 있다.
  final int? senderId;

  /// 'TEXT' 또는 'SYSTEM'.
  final String type;

  final String? content;

  /// 시스템 메시지의 구조화 정보. kind 로 종류를 가른다.
  final Map<String, dynamic>? systemPayload;

  final DateTime? createdAt;

  /// 이 메시지를 아직 읽지 않은 사람 수.
  final int unreadCount;

  /// 보낸 쪽이 붙였던 임시 식별자. 방금 보낸 것을 되받을 때만 실린다.
  final String? clientMsgId;

  const ChatMessageResponse({
    required this.roomId,
    required this.seq,
    required this.senderId,
    required this.type,
    required this.content,
    required this.systemPayload,
    required this.createdAt,
    required this.unreadCount,
    required this.clientMsgId,
  });

  factory ChatMessageResponse.fromJson(Map<String, dynamic> json) =>
      ChatMessageResponse(
        roomId: _int(json['room_id']),
        seq: _int(json['seq']),
        senderId: (json['sender_id'] as num?)?.toInt(),
        type: json['type'] as String? ?? 'TEXT',
        content: json['content'] as String?,
        systemPayload: json['system_payload'] as Map<String, dynamic>?,
        createdAt: _time(json['created_at']),
        unreadCount: _int(json['unread_count']),
        clientMsgId: json['client_msg_id'] as String?,
      );
}

/// 지난 대화 한 페이지.
class ChatHistoryResponse {
  final List<ChatMessageResponse> messages;

  /// 더 과거를 읽을 때 넘길 순번. 없으면 더 읽을 것이 없다.
  final int? nextCursor;

  const ChatHistoryResponse({required this.messages, required this.nextCursor});

  factory ChatHistoryResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['messages'];
    return ChatHistoryResponse(
      messages: raw is List
          ? raw
                .whereType<Map<String, dynamic>>()
                .map(ChatMessageResponse.fromJson)
                .toList()
          : const [],
      nextCursor: (json['next_cursor'] as num?)?.toInt(),
    );
  }
}

/// 안 읽은 개수 응답.
class ChatUnreadResponse {
  final int roomId;
  final int unreadCount;
  final int lastReadSeq;
  final int latestSeq;

  const ChatUnreadResponse({
    required this.roomId,
    required this.unreadCount,
    required this.lastReadSeq,
    required this.latestSeq,
  });

  factory ChatUnreadResponse.fromJson(Map<String, dynamic> json) =>
      ChatUnreadResponse(
        roomId: _int(json['room_id']),
        unreadCount: _int(json['unread_count']),
        lastReadSeq: _int(json['last_read_seq']),
        latestSeq: _int(json['latest_seq']),
      );
}

/// 참가자 한 명.
class ChatParticipantResponse {
  final int userId;
  final String? nickname;

  /// 'OWNER' 또는 'MEMBER'.
  final String role;

  /// 'ACTIVE' / 'LEFT' / 'KICKED'.
  final String status;

  final int lastReadSeq;
  final DateTime? joinedAt;

  const ChatParticipantResponse({
    required this.userId,
    required this.nickname,
    required this.role,
    required this.status,
    required this.lastReadSeq,
    required this.joinedAt,
  });

  factory ChatParticipantResponse.fromJson(Map<String, dynamic> json) =>
      ChatParticipantResponse(
        userId: _int(json['user_id']),
        nickname: json['nickname'] as String?,
        role: json['role'] as String? ?? 'MEMBER',
        status: json['status'] as String? ?? 'ACTIVE',
        lastReadSeq: _int(json['last_read_seq']),
        joinedAt: _time(json['joined_at']),
      );
}

/// 채팅 REST 호출 모음.
///
/// 실시간 경로가 끊겨 있어도 대화를 읽고 보낼 수 있어야 하므로, 소켓으로 하는
/// 일은 전부 여기에도 같은 기능이 있다. 소켓은 빠르게 받기 위한 길이지 유일한
/// 길이 아니다.
class ChatApiService {
  ChatApiService._();
  static final ChatApiService instance = ChatApiService._();

  final _api = ApiClient.instance;

  static const _base = '/api/v1/chat';

  /// 일정에 딸린 방을 만들거나, 이미 있으면 그것을 가져온다.
  ///
  /// 방은 일정 하나에 하나뿐이라 여러 번 불러도 같은 방이 돌아온다.
  Future<ChatRoomResponse> createOrGetRoom(int scheduleId) async {
    final json = await _api.post(
      '$_base/rooms',
      body: {'schedule_id': scheduleId},
    );
    return ChatRoomResponse.fromJson(json);
  }

  Future<ChatRoomResponse> getRoom(int roomId) async {
    final json = await _api.get('$_base/rooms/$roomId');
    return ChatRoomResponse.fromJson(json);
  }

  Future<ChatRoomResponse> getRoomBySchedule(int scheduleId) async {
    final json = await _api.get('$_base/rooms/by-schedule/$scheduleId');
    return ChatRoomResponse.fromJson(json);
  }

  Future<List<ChatRoomSummary>> listRooms() async {
    final rows = await _api.getList('$_base/rooms');
    return rows
        .whereType<Map<String, dynamic>>()
        .map(ChatRoomSummary.fromJson)
        .toList();
  }

  /// 지난 대화를 최신부터 읽는다. [beforeSeq] 를 주면 그 순번보다 앞을 읽는다.
  Future<ChatHistoryResponse> history(
    int roomId, {
    int? beforeSeq,
    int? limit,
  }) async {
    final query = <String, String>{};
    if (beforeSeq != null) query['before_seq'] = '$beforeSeq';
    if (limit != null) query['limit'] = '$limit';
    final json = await _api.get('$_base/rooms/$roomId/messages', query: query);
    return ChatHistoryResponse.fromJson(json);
  }

  /// 소켓이 끊겼을 때 쓰는 전송 경로.
  Future<ChatMessageResponse> send(
    int roomId,
    String content,
    String clientMsgId,
  ) async {
    final json = await _api.post(
      '$_base/rooms/$roomId/messages',
      body: {'content': content, 'client_msg_id': clientMsgId},
    );
    return ChatMessageResponse.fromJson(json);
  }

  Future<ChatUnreadResponse> markRead(int roomId, int lastReadSeq) async {
    final json = await _api.post(
      '$_base/rooms/$roomId/read',
      body: {'last_read_seq': lastReadSeq},
    );
    return ChatUnreadResponse.fromJson(json);
  }

  Future<ChatUnreadResponse> unread(int roomId) async {
    final json = await _api.get('$_base/rooms/$roomId/unread');
    return ChatUnreadResponse.fromJson(json);
  }

  Future<List<ChatParticipantResponse>> participants(int roomId) async {
    final rows = await _api.getList('$_base/rooms/$roomId/participants');
    return rows
        .whereType<Map<String, dynamic>>()
        .map(ChatParticipantResponse.fromJson)
        .toList();
  }

  /// 지금 접속해 있는 사람들의 식별자.
  Future<List<int>> presence(int roomId) async {
    final rows = await _api.getList('$_base/rooms/$roomId/presence');
    return rows.whereType<num>().map((e) => e.toInt()).toList();
  }

  Future<void> leave(int roomId) =>
      _api.delete('$_base/rooms/$roomId/participants/me');

  Future<void> kick(int roomId, int userId) =>
      _api.delete('$_base/rooms/$roomId/participants/$userId');
}
