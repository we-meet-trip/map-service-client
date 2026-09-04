import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/api/api_client.dart';
import 'package:map_service_client/core/api/chat_realtime_service.dart';
import 'package:map_service_client/data/models/chat_message.dart';
import 'package:map_service_client/data/models/chat_room.dart';
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
      _FailingRepository(const ApiException(
        statusCode: 408,
        code: 'REQUEST_TIMEOUT',
        message: '응답이 지연되고 있어요.',
      )),
      realtime,
    );

    await provider.sendMessage('느린 망에서 보낸 말');

    expect(provider.hasUnsent, isTrue);
    expect(provider.messages.single.pending, isTrue);
  });

  test('서버가 거절하면 말풍선을 걷고 사유를 보여준다', () async {
    final realtime = _FakeRealtime();
    final provider = _provider(
      _FailingRepository(const ApiException(
        statusCode: 403,
        code: 'CHAT_003',
        message: '참가자가 아닙니다.',
      )),
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

  test('다시 붙으면 보관해 둔 말이 순서대로 나간다', () async {
    final realtime = _FakeRealtime();
    final provider = _provider(_FailingRepository(_networkDown), realtime);
    await provider.open(readOnly: false);

    await provider.sendMessage('첫째');
    await provider.sendMessage('둘째');
    expect(realtime.sent, isEmpty);

    realtime.becomeConnected();
    await Future<void>.delayed(Duration.zero);

    // 순서가 뒤집히면 대화가 뒤섞인다.
    expect(realtime.sent, ['첫째', '둘째']);
    expect(provider.hasUnsent, isFalse);
  });

  test('보관이 상한을 넘으면 오래된 것부터 버린다', () async {
    final realtime = _FakeRealtime();
    final provider = _provider(_FailingRepository(_networkDown), realtime);
    await provider.open(readOnly: false);

    // 오래 끊긴 뒤 한꺼번에 밀려 나가면 서버의 전송 한도에 걸린다.
    for (var i = 1; i <= 25; i++) {
      await provider.sendMessage('말$i');
    }

    realtime.becomeConnected();
    await Future<void>.delayed(Duration.zero);

    // 최근 것을 버리면 방금 친 말이 사라져 더 이상하게 보인다.
    expect(realtime.sent.length, 20);
    expect(realtime.sent.first, '말6');
    expect(realtime.sent.last, '말25');
  });
}

ChatRoomDetailProvider _provider(ChatRepository repository, _FakeRealtime rt) =>
    ChatRoomDetailProvider(repository, _StubInviteLinks(), 7, realtime: rt);

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

  final Object failure;

  @override
  Future<ChatMessage> sendMessage(
          int roomId, String text, String clientMsgId) async =>
      throw failure;

  @override
  Future<List<ChatMessage>> getMessages(int roomId, {int? beforeSeq}) async =>
      const [];

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
}

class _StubInviteLinks implements InviteLinkRepository {
  @override
  Future<InviteLink> generateInviteLink(int roomId) async =>
      throw UnimplementedError();
}
