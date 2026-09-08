import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/api/api_client.dart';
import 'package:map_service_client/core/api/chat_realtime_service.dart';
import 'package:map_service_client/core/api/moderation_api_service.dart';
import 'package:map_service_client/data/local/chat_outbox_store.dart';
import 'package:map_service_client/data/models/chat_message.dart';
import 'package:map_service_client/data/repositories/api_chat_repository.dart';
import 'package:map_service_client/data/repositories/invite_link_repository.dart';
import 'package:map_service_client/features/chat/providers/chat_room_detail_provider.dart';

ChatMessage message(int seq, int sender) => ChatMessage(
  roomId: 7,
  seq: seq,
  senderId: sender,
  senderName: '공개 시험 사용자',
  text: '시험 메시지 $seq',
  sentAt: DateTime(2026, 9, 7, 9, seq),
  isMe: false,
);

class Repo extends ApiChatRepository {
  List<ChatMessage> held = [message(1, 9), message(2, 10)];
  Completer<List<ChatMessage>>? pending;
  int reads = 0;
  @override
  Future<List<ChatMessage>> getMessages(int roomId, {int? beforeSeq}) async {
    reads++;
    return pending == null ? List.of(held) : pending!.future;
  }

  @override
  Future<void> markAsRead(int roomId, int lastReadSeq) async {}
}

class ModerationApi extends ApiClientFake {
  Completer<Map<String, dynamic>>? pending;
  bool failBlock = false;
  List<Map<String, dynamic>> blocked = [];
  @override
  Future<Map<String, dynamic>> put(
    String path, {
    Object? body,
    Duration? timeout,
  }) async {
    if (failBlock) throw StateError('server rejected');
    return pending == null ? {} : pending!.future;
  }

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) async => {'data': blocked};
}

class ApiClientFake implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
  void dispose() {
    controller.close();
  }

  void send(int seq, int sender) => controller.add(
    ChatEvent.parse(
      '{"type":"MESSAGE","room_id":7,"data":{"room_id":7,"seq":$seq,"sender_id":$sender,"type":"TEXT","content":"공개 시험","created_at":"2026-09-07T01:00:00Z"}}',
    ),
  );
  void remove(int seq, {int room = 7}) => controller.add(
    ChatEvent.parse(
      '{"type":"MESSAGE_REMOVED","room_id":$room,"data":{"seq":$seq}}',
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
  late Repo repo;
  late Realtime rt;
  late ModerationApi api;
  late ChatRoomDetailProvider provider;
  setUp(() async {
    repo = Repo();
    rt = Realtime();
    api = ModerationApi();
    provider = ChatRoomDetailProvider(
      repo,
      Invites(),
      7,
      realtime: rt,
      outboxStore: Outbox(),
      moderation: ModerationApiService(api: api),
    );
    await provider.open(readOnly: false);
  });
  tearDown(() => provider.dispose());
  test(
    'successful block hides existing and newly delivered messages and reloads history',
    () async {
      final previousReads = repo.reads;
      await provider.blockUser(9);
      expect(provider.messages.map((m) => m.senderId), [10]);
      expect(repo.reads, greaterThan(previousReads));
      rt.send(3, 9);
      rt.send(4, 10);
      expect(provider.messages.map((m) => m.seq), unorderedEquals([2, 4]));
    },
  );
  test('rejected block retains messages and does not claim success', () async {
    api.failBlock = true;
    await expectLater(provider.blockUser(9), throwsStateError);
    expect(provider.messages.map((m) => m.seq), [1, 2]);
  });
  test(
    'removal event cannot be undone by a pre-removal history response',
    () async {
      repo.pending = Completer();
      final oldLoad = provider.loadMessages();
      rt.remove(1);
      expect(provider.messages.map((m) => m.seq), [2]);
      repo.pending!.complete(List.of(repo.held));
      await oldLoad;
      await Future<void>.delayed(Duration.zero);
      expect(provider.messages.map((m) => m.seq), [2]);
      rt.send(1, 9);
      expect(provider.messages.map((m) => m.seq), [2]);
    },
  );
  test(
    'unblock refresh restores only the history returned by the server',
    () async {
      await provider.blockUser(9);
      api.blocked = [];
      await provider.refreshBlocks();
      expect(provider.messages.map((m) => m.seq), [1, 2]);
    },
  );
  test('removal for another room cannot hide this room content', () {
    rt.remove(1, room: 8);
    expect(provider.messages.map((m) => m.seq), [1, 2]);
  });
}
