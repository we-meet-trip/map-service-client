import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/api/api_client.dart';
import 'package:map_service_client/core/api/chat_realtime_service.dart';
import 'package:map_service_client/data/models/chat_message.dart';
import 'package:map_service_client/data/models/chat_room.dart';
import 'package:map_service_client/data/local/chat_outbox_store.dart';
import 'package:map_service_client/data/repositories/chat_repository.dart';
import 'package:map_service_client/data/repositories/invite_link_repository.dart';
import 'package:map_service_client/features/chat/providers/chat_room_detail_provider.dart';

/// 나가지 못한 말을 어떻게 다루는지 본다.
///
/// 소켓이 죽어도 REST 가 대신 보내 주지만, 소켓이 죽는 상황은 대개 망이 나쁜
/// 상황이라 REST 도 함께 실패한다. 터널·엘리베이터처럼 여행 중에 흔하다.
/// 그때 버리면 사용자는 다시 쳐야 하는데, 무엇을 다시 쳐야 하는지는 이미
/// 화면에서 사라진 뒤다.
///
/// 반대로 서버가 답을 한 거절(참가자가 아님, 너무 김)은 다시 보내도 결과가
/// 같으므로 보관하면 안 된다. 이 둘을 가르는 것이 이 시험의 요점이다.
void main() {
  test('망이 끊기면 말풍선을 남기고 보관한다', () async {
    final realtime = _FakeRealtime();
    final provider = _provider(_FailingRepository(_networkDown), realtime);

    await provider.sendMessage('터널에서 보낸 말');

    // 걷어내면 사용자는 무엇을 다시 쳐야 하는지 알 수 없다.
    expect(provider.messages.single.text, '터널에서 보낸 말');
    expect(provider.messages.single.pending, isTrue);
    expect(provider.hasUnsent, isTrue);
    expect(provider.consumeSendError(), isNull);
  });

  test('응답이 지연돼도 보관한다', () async {
    // 서버의 판단이 아니라 길이 막힌 것에 가깝다.
    final realtime = _FakeRealtime();
    final provider = _provider(
      _FailingRepository(
        const ApiException(
          statusCode: 408,
          code: 'REQUEST_TIMEOUT',
          message: '응답이 지연되고 있어요.',
        ),
      ),
      realtime,
    );

    await provider.sendMessage('느린 망에서 보낸 말');

    expect(provider.hasUnsent, isTrue);
    expect(provider.messages.single.pending, isTrue);
  });

  test('서버가 거절하면 말풍선을 걷고 사유를 보여준다', () async {
    final realtime = _FakeRealtime();
    final provider = _provider(
      _FailingRepository(
        const ApiException(
          statusCode: 403,
          code: 'CHAT_003',
          message: '참가자가 아닙니다.',
        ),
      ),
      realtime,
    );

    await provider.sendMessage('남의 방에 보낸 말');

    // 다시 보내도 같은 답이 온다. 보관하면 영영 나가지 못할 것을 들고 있게 된다.
    expect(provider.hasUnsent, isFalse);
    expect(provider.messages, isEmpty);
    // 사유는 서버가 준 것을 그대로 쓴다. 우리가 새로 지으면 서버가 문구를
    // 바꿔도 옛 문구가 남는다.
    expect(provider.consumeSendError(), '참가자가 아닙니다.');
  });

  test('다시 붙으면 같은 식별자로 저장 확인을 받고 순서대로 비운다', () async {
    final realtime = _FakeRealtime();
    final repository = _FailingRepository(_networkDown);
    final provider = _provider(repository, realtime);
    await provider.open(readOnly: false);

    await provider.sendMessage('첫째');
    await provider.sendMessage('둘째');
    expect(realtime.sent, isEmpty);

    final ids = provider.messages.map((m) => m.clientMsgId).toList();
    repository.failure = null;
    repository.accepted.clear();
    realtime.becomeConnected();
    await Future<void>.delayed(Duration.zero);

    // 순서가 뒤집히면 대화가 뒤섞인다.
    expect(repository.accepted.map((m) => m.text), ['첫째', '둘째']);
    expect(repository.accepted.map((m) => m.clientMsgId), ids);
    expect(provider.hasUnsent, isFalse);
    expect(provider.messages.every((m) => !m.pending), isTrue);
  });

  test('보관 상한에서 이미 보관한 메시지를 조용히 버리지 않는다', () async {
    final realtime = _FakeRealtime();
    final provider = _provider(_FailingRepository(_networkDown), realtime);
    await provider.open(readOnly: false);

    // 오래 끊긴 뒤 한꺼번에 밀려 나가면 서버의 전송 한도에 걸린다.
    for (var i = 1; i <= 25; i++) {
      await provider.sendMessage('말$i');
    }

    realtime.becomeConnected();
    await Future<void>.delayed(Duration.zero);

    expect(provider.messages.length, 20);
    expect(provider.messages.first.text, '말1');
    expect(provider.messages.last.text, '말20');
    expect(provider.hasUnsent, isTrue);
    expect(provider.consumeSendError(), isNotNull);
  });

  test('화면을 닫았다 다시 열어도 미확인 메시지와 식별자가 복원된다', () async {
    final store = _MemoryOutbox();
    final first = ChatRoomDetailProvider(
      _FailingRepository(_networkDown),
      _StubInviteLinks(),
      7,
      realtime: _FakeRealtime(),
      outboxStore: store,
    );
    await first.sendMessage('보관할 말');
    final id = first.messages.single.clientMsgId;
    first.dispose();
    final second = ChatRoomDetailProvider(
      _FailingRepository(_networkDown),
      _StubInviteLinks(),
      7,
      realtime: _FakeRealtime(),
      outboxStore: store,
    );
    addTearDown(second.dispose);
    await second.open(readOnly: false);
    expect(second.messages.single.clientMsgId, id);
    expect(second.messages.single.text, '보관할 말');
    expect(second.hasUnsent, isTrue);
  });

  test('저장 응답을 잃고 재조회한 경우 화면에 중복 메시지가 생기지 않는다', () async {
    final repository = _FailingRepository(_networkDown);
    final provider = _provider(repository, _FakeRealtime());
    await provider.sendMessage('중복 금지');
    final pending = provider.messages.single;
    repository.history = [
      ChatMessage(
        roomId: 7,
        seq: 1,
        senderId: 1,
        senderName: '나',
        text: pending.text,
        sentAt: pending.sentAt,
        isMe: true,
        clientMsgId: pending.clientMsgId,
      ),
    ];
    await provider.loadMessages();
    expect(provider.messages.length, 1);
    expect(provider.messages.single.pending, isFalse);
    expect(provider.hasUnsent, isFalse);
  });
}

ChatRoomDetailProvider _provider(ChatRepository repository, _FakeRealtime rt) {
  final provider = ChatRoomDetailProvider(
    repository,
    _StubInviteLinks(),
    7,
    realtime: rt,
    outboxStore: _MemoryOutbox(),
  );
  addTearDown(provider.dispose);
  return provider;
}

class _MemoryOutbox extends ChatOutboxStore {
  _MemoryOutbox() : super(7);
  List<PendingChatMessage> held = [];
  @override
  Future<List<PendingChatMessage>> load() async => List.of(held);
  @override
  Future<void> save(List<PendingChatMessage> messages) async {
    held = List.of(messages);
  }
}

/// 망이 끊겼을 때 올라오는 모양. 공통 계층이 서버 오류로 바꿔 주지 못한다.
final _networkDown = StateError('연결 끊김');

/// 붙었는지 여부와 보낸 것만 흉내 낸다. 실제 소켓은 열지 않는다.
class _FakeRealtime extends ChatRealtimeService {
  final List<String> sent = [];
  final _stateController = StreamController<ChatConnectionState>.broadcast();
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Stream<ChatConnectionState> get states => _stateController.stream;

  @override
  Stream<ChatEvent> get events => const Stream<ChatEvent>.empty();

  @override
  Stream<void> get reconnected => const Stream<void>.empty();

  @override
  void connect(int roomId) {}

  @override
  void disconnect() {}

  @override
  void sendMessage(int roomId, String content, String clientMsgId) =>
      sent.add(content);

  void becomeConnected() {
    _connected = true;
    _stateController.add(ChatConnectionState.connected);
  }
}

/// 무엇을 보내든 정해진 실패를 돌려준다.
class _FailingRepository implements ChatRepository {
  _FailingRepository(this.failure);

  Object? failure;
  final List<ChatMessage> accepted = [];
  List<ChatMessage> history = [];

  @override
  Future<ChatMessage> sendMessage(
    int roomId,
    String text,
    String clientMsgId,
  ) async {
    if (failure != null) throw failure!;
    final message = ChatMessage(
      roomId: roomId,
      seq: accepted.length + 1,
      senderId: 1,
      senderName: '나',
      text: text,
      sentAt: DateTime.now(),
      isMe: true,
      clientMsgId: clientMsgId,
    );
    accepted.add(message);
    return message;
  }

  @override
  Future<List<ChatMessage>> getMessages(int roomId, {int? beforeSeq}) async =>
      history;

  @override
  Future<List<ChatRoom>> getChatRooms() async => const [];

  @override
  Future<ChatRoom> getRoom(int roomId) async => throw UnimplementedError();

  @override
  Future<ChatRoom> createChatRoomForSchedule(int scheduleId) async =>
      throw UnimplementedError();

  @override
  Future<void> markAsRead(int roomId, int lastReadSeq) async {}

  @override
  Future<List<ChatUser>> getParticipants(int roomId) async => const [];

  @override
  Future<void> leave(int roomId) async {}

  @override
  Future<void> kick(int roomId, int userId) async {}
}

class _StubInviteLinks implements InviteLinkRepository {
  @override
  Future<InviteLink> generateInviteLink(int roomId) async =>
      throw UnimplementedError();
}
