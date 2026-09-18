import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/api/chat_realtime_service.dart';
import 'package:map_service_client/core/state/auth_store.dart';
import 'package:map_service_client/data/local/chat_outbox_store.dart';
import 'package:map_service_client/data/models/chat_message.dart';
import 'package:map_service_client/data/repositories/api_chat_repository.dart';
import 'package:map_service_client/data/repositories/invite_link_repository.dart';
import 'package:map_service_client/features/chat/providers/chat_room_detail_provider.dart';

/// 조회가 읽음을 올리고 그 읽음이 다시 조회를 부르면 방을 열어 둔 내내 멈추지 않는다.
/// 화면은 그 사이 계속 비워졌다 그려져 깜빡이고, 대화는 거의 보이지 않는다.
ChatMessage peerMessage(int seq) => ChatMessage(
  roomId: 7,
  seq: seq,
  senderId: 9,
  senderName: '상대',
  text: '메시지 $seq',
  sentAt: DateTime(2026, 9, 16, 9, seq),
  isMe: false,
);

class Repo extends ApiChatRepository {
  List<ChatMessage> held = [peerMessage(1), peerMessage(2)];
  int reads = 0;
  List<int> acked = [];

  @override
  Future<List<ChatMessage>> getMessages(int roomId, {int? beforeSeq}) async {
    reads++;
    return List.of(held);
  }

  @override
  Future<void> markAsRead(int roomId, int lastReadSeq) async {
    acked.add(lastReadSeq);
  }
}

class Realtime extends ChatRealtimeService {
  final controller = StreamController<ChatEvent>.broadcast(sync: true);
  @override
  Stream<ChatEvent> get events => controller.stream;
  @override
  Stream<ChatConnectionState> get states => const Stream.empty();
  @override
  Stream<void> get reconnected => const Stream.empty();
  @override
  void connect(int roomId) {}
  @override
  void disconnect() {}
  @override
  void dispose() => controller.close();

  void readBy(int userId, int lastReadSeq) => controller.add(
    ChatEvent.parse(
      '{"type":"READ","room_id":7,'
      '"data":{"user_id":$userId,"last_read_seq":$lastReadSeq}}',
    ),
  );

  void message(int seq, int sender) => controller.add(
    ChatEvent.parse(
      '{"type":"MESSAGE","room_id":7,"data":{"room_id":7,"seq":$seq,'
      '"sender_id":$sender,"type":"TEXT","content":"본문",'
      '"created_at":"2026-09-16T01:00:00Z"}}',
    ),
  );
}

class Outbox extends ChatOutboxStore {
  Outbox() : super(7);
  @override
  Future<List<PendingChatMessage>> load() async => [];
  @override
  Future<void> save(List<PendingChatMessage> messages) async {}
}

class Invites implements InviteLinkRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Repo repo;
  late Realtime rt;
  late ChatRoomDetailProvider provider;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
    await AuthStore.instance.save(
      const AuthTokens(
        accessToken: 'a',
        refreshToken: 'r',
        userId: 1,
      ),
    );
    repo = Repo();
    rt = Realtime();
    provider = ChatRoomDetailProvider(
      repo,
      Invites(),
      7,
      realtime: rt,
      outboxStore: Outbox(),
    );
    await provider.open(readOnly: false);
  });

  tearDown(() => provider.dispose());

  test('방을 열면 읽음을 한 번만 올린다', () {
    expect(repo.acked, [2]);
    expect(repo.reads, 1);
  });

  test('같은 자리를 다시 확인해도 읽음을 또 올리지 않는다', () async {
    await provider.loadMessages();

    expect(repo.reads, 2);
    // 위치가 그대로면 올릴 것이 없다. 올리면 서버가 그것을 알리고,
    // 그 알림이 다시 조회를 불러 끝나지 않는다.
    expect(repo.acked, [2]);
  });

  test('남이 읽었다는 알림은 한 번 조회하고 거기서 멈춘다', () async {
    rt.readBy(9, 2);
    await Future<void>.delayed(Duration.zero);

    expect(repo.reads, 2);
    expect(repo.acked, [2]);
  });

  test('내가 올린 읽음이 되돌아오면 다시 조회하지 않는다', () async {
    rt.readBy(1, 2);
    await Future<void>.delayed(Duration.zero);

    expect(repo.reads, 1);
    expect(repo.acked, [2]);
  });

  test('상대 메시지가 오면 읽음이 그만큼 올라가고, 같은 것에 또 올리지 않는다', () async {
    repo.held = [...repo.held, peerMessage(3)];
    rt.message(3, 9);
    await Future<void>.delayed(Duration.zero);

    expect(repo.acked, [2, 3]);

    rt.message(3, 9);
    await Future<void>.delayed(Duration.zero);

    expect(repo.acked, [2, 3]);
  });
}
