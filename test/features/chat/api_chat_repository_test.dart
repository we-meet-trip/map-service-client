import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/api/chat_api_service.dart';
import 'package:map_service_client/data/models/chat_message.dart';
import 'package:map_service_client/data/models/chat_room.dart';
import 'package:map_service_client/data/repositories/api_chat_repository.dart';

class _FakeChatApi implements ChatApiService {
  _FakeChatApi({
    this.rooms = const [],
    this.messages = const [],
    this.people = const [],
  });

  final List<ChatRoomSummary> rooms;
  final List<ChatMessageResponse> messages;
  final List<ChatParticipantResponse> people;

  @override
  Future<List<ChatRoomSummary>> listRooms() async => rooms;

  @override
  Future<ChatHistoryResponse> history(
    int roomId, {
    int? beforeSeq,
    int? limit,
  }) async => ChatHistoryResponse(messages: messages, nextCursor: null);

  @override
  Future<List<ChatParticipantResponse>> participants(int roomId) async =>
      people;

  @override
  Future<ChatRoomResponse> createOrGetRoom(int scheduleId) =>
      throw UnimplementedError();
  @override
  Future<ChatRoomResponse> getRoom(int roomId) => throw UnimplementedError();
  @override
  Future<ChatRoomResponse> getRoomBySchedule(int scheduleId) =>
      throw UnimplementedError();
  @override
  Future<ChatMessageResponse> send(
    int roomId,
    String content,
    String clientMsgId,
  ) => throw UnimplementedError();
  @override
  Future<ChatUnreadResponse> markRead(int roomId, int lastReadSeq) =>
      throw UnimplementedError();
  @override
  Future<ChatUnreadResponse> unread(int roomId) => throw UnimplementedError();
  @override
  Future<List<int>> presence(int roomId) => throw UnimplementedError();
  final leaveCalls = <int>[];
  final kickCalls = <String>[];
  @override
  Future<void> leave(int roomId) async {
    leaveCalls.add(roomId);
  }

  @override
  Future<void> kick(int roomId, int userId) async {
    kickCalls.add('$roomId:$userId');
  }
}

ChatParticipantResponse _person(
  int id,
  String name, {
  String status = 'ACTIVE',
}) => ChatParticipantResponse(
  userId: id,
  nickname: name,
  role: id == 1 ? 'OWNER' : 'MEMBER',
  status: status,
  lastReadSeq: 0,
  joinedAt: DateTime.now(),
);

ChatMessageResponse _message(int seq, {int? senderId, String type = 'TEXT'}) =>
    ChatMessageResponse(
      roomId: 7,
      seq: seq,
      senderId: senderId,
      type: type,
      content: '내용 $seq',
      systemPayload: type == 'SYSTEM' ? {'kind': 'JOIN', 'user_id': 2} : null,
      createdAt: DateTime.now(),
      unreadCount: 1,
      clientMsgId: null,
    );

ChatRoomSummary _summary({bool readOnly = false, DateTime? lastAt}) =>
    ChatRoomSummary(
      roomId: 7,
      scheduleId: 11,
      title: '속초 당일치기',
      readOnly: readOnly,
      unreadCount: 3,
      lastMessage: '내일 봐요',
      lastMessageAt: lastAt,
      latestSeq: 9,
      participantCount: 2,
    );

void main() {
  test('일정이 삭제된 방은 목록에서도 null 일정을 보존한다', () async {
    final repository = ApiChatRepository(
      api: _FakeChatApi(
        rooms: [
          ChatRoomSummary.fromJson({
            'room_id': 7,
            'schedule_id': null,
            'title': '보관된 대화',
            'read_only': true,
          }),
        ],
      ),
    );
    final room = (await repository.getChatRooms()).single;
    expect(room.id, 7);
    expect(room.scheduleId, isNull);
    expect(room.copyWith(unreadCount: 1).scheduleId, isNull);
  });

  test('익명화된 보낸 사람은 0번 사용자나 내 메시지로 바뀌지 않는다', () async {
    final repository = ApiChatRepository(
      api: _FakeChatApi(messages: [_message(3, senderId: null)]),
    );
    final message = (await repository.getMessages(7)).single;
    expect(message.senderId, isNull);
    expect(message.isMe, isFalse);
    expect(message.senderName, '알 수 없음');
    expect(message.type, ChatMessageType.text);
    expect(message.text, '내용 3');
  });

  test('목록은 방 번호와 일정 번호를 서로 다른 값으로 옮긴다', () async {
    // 둘을 같은 것으로 두면 "일정 보러가기"가 조용히 아무 데도 닿지 않는다.
    final repository = ApiChatRepository(
      api: _FakeChatApi(rooms: [_summary()]),
    );

    final rooms = await repository.getChatRooms();

    expect(rooms.single.id, 7);
    expect(rooms.single.scheduleId, 11);
    expect(rooms.single.hasUnread, isTrue);
  });

  test('보관된 방은 지난 방으로 분류된다', () async {
    final repository = ApiChatRepository(
      api: _FakeChatApi(rooms: [_summary(readOnly: true)]),
    );

    final rooms = await repository.getChatRooms();

    expect(rooms.single.type, ChatRoomType.past);
  });

  test('대화가 없는 방은 정렬에서 뒤로 밀리도록 아주 과거를 쓴다', () async {
    final repository = ApiChatRepository(
      api: _FakeChatApi(rooms: [_summary()]),
    );

    final rooms = await repository.getChatRooms();

    expect(rooms.single.lastMessageAt, isNull);
    expect(rooms.single.sortedAt.millisecondsSinceEpoch, 0);
  });

  test('보낸 사람 이름은 참가자 목록에서 찾아 붙인다', () async {
    final repository = ApiChatRepository(
      api: _FakeChatApi(
        messages: [_message(2, senderId: 2)],
        people: [_person(1, '나'), _person(2, '지수')],
      ),
    );

    final messages = await repository.getMessages(7);

    expect(messages.single.senderName, '지수');
  });

  test('나간 사람의 대화도 이름만 대체해 그대로 남긴다', () async {
    // 이름을 못 찾았다고 줄 자체를 빼면 대화의 흐름이 끊긴 것처럼 보인다.
    final repository = ApiChatRepository(
      api: _FakeChatApi(
        messages: [_message(2, senderId: 99)],
        people: [_person(1, '나')],
      ),
    );

    final messages = await repository.getMessages(7);

    expect(messages, hasLength(1));
    expect(messages.single.senderName, '알 수 없음');
  });

  test('안내 메시지는 보낸 사람 없이 구조화 정보를 들고 온다', () async {
    final repository = ApiChatRepository(
      api: _FakeChatApi(
        messages: [_message(1, type: 'SYSTEM')],
        people: [_person(1, '나')],
      ),
    );

    final messages = await repository.getMessages(7);

    expect(messages.single.type, ChatMessageType.system);
    expect(messages.single.senderId, isNull);
    expect(messages.single.systemPayload?['kind'], 'JOIN');
  });

  test('지난 대화는 오래된 것부터 오도록 뒤집어 준다', () async {
    // 서버는 최신부터 내려 주고 화면은 위에서 아래로 읽는다.
    final repository = ApiChatRepository(
      api: _FakeChatApi(
        messages: [
          _message(3, senderId: 1),
          _message(2, senderId: 1),
          _message(1, senderId: 1),
        ],
        people: [_person(1, '나')],
      ),
    );

    final messages = await repository.getMessages(7);

    expect(messages.map((m) => m.seq), [1, 2, 3]);
  });

  test('나가기는 방 번호 그대로 API 에 위임한다', () async {
    final api = _FakeChatApi();
    final repository = ApiChatRepository(api: api);

    await repository.leave(7);

    expect(api.leaveCalls, [7]);
  });

  test('내보내기는 방 번호와 대상 번호 그대로 API 에 위임한다', () async {
    final api = _FakeChatApi();
    final repository = ApiChatRepository(api: api);

    await repository.kick(7, 2);

    expect(api.kickCalls, ['7:2']);
  });
}
