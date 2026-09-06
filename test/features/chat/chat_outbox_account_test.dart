import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:map_service_client/core/api/api_client.dart';
import 'package:map_service_client/core/api/auth_api_service.dart';
import 'package:map_service_client/core/config/app_config.dart';
import 'package:map_service_client/core/state/auth_store.dart';
import 'package:map_service_client/data/local/chat_outbox_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final auth = AuthStore.instance;
  final values = <String, String>{};
  final scope = AppConfig.instance.storageScope;
  var account = 1000;
  Future<void> Function(String)? beforeWrite;
  final draft = PendingChatMessage(
    'pending text',
    'pending-id',
    DateTime.utc(2026, 9, 6),
  );

  Future<ChatOutboxStore> login(int user, int room) async {
    await auth.save(
      AuthTokens(
        accessToken: 'account-$user',
        refreshToken: 'refresh-$user',
        userId: user,
      ),
    );
    return ChatOutboxStore(room);
  }

  setUp(() async {
    beforeWrite = null;
    account += 10;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'readAll') return Map<String, String>.from(values);
          final key = call.arguments['key'] as String;
          switch (call.method) {
            case 'read':
              return values[key];
            case 'write':
              await beforeWrite?.call(key);
              values[key] = call.arguments['value'] as String;
            case 'delete':
              values.remove(key);
          }
          return null;
        });
    await auth.clear();
    values.clear();
  });

  test(
    'withdrawal deletes every room only for that account and environment',
    () async {
      final a7 = await login(account, 7);
      final a8 = ChatOutboxStore(8);
      await a7.save([draft]);
      await a8.save([draft]);
      final b7 = await login(account + 1, 7);
      await b7.save([draft]);
      final otherEnvironment =
          'chat.outbox:prod:https://another.example:$account:7';
      values[otherEnvironment] = 'other-environment-draft';
      final neighboringAccount = 'chat.outbox:$scope:${account}1:7';
      values[neighboringAccount] = 'neighbor-draft';
      values['unrelated.preference'] = 'keep';

      await ChatOutboxStore.deleteAccount(scope, account);
      expect(await a7.load(), isEmpty);
      expect(await a8.load(), isEmpty);
      expect((await b7.load()).single.clientMsgId, 'pending-id');
      expect(values[otherEnvironment], 'other-environment-draft');
      expect(values[neighboringAccount], 'neighbor-draft');
      expect(values['unrelated.preference'], 'keep');

      await a7.save([draft]); // A retired controller still holds the old store.
      expect(await a7.load(), isEmpty);
      expect((await b7.load()).single.text, 'pending text');
    },
  );

  test(
    'withdrawal waits for an in-flight write and blocks queued and stale writes',
    () async {
      final store = await login(account, 7);
      final key = 'chat.outbox:$scope:$account:7';
      final started = Completer<void>();
      final release = Completer<void>();
      beforeWrite = (actual) async {
        if (actual == key) {
          if (!started.isCompleted) started.complete();
          await release.future;
        }
      };
      final first = store.save([draft]);
      await started.future;
      final queued = store.save([draft, draft]);
      final deletion = ChatOutboxStore.deleteAccount(scope, account);
      await store.save([draft]);
      release.complete();
      await Future.wait([first, queued, deletion]);
      expect(values.containsKey(key), isFalse);
      expect(await store.load(), isEmpty);
    },
  );

  test('ordinary logout keeps each account draft for a later login', () async {
    final first = await login(account, 7);
    await first.save([draft]);
    await auth.clear();
    final other = await login(account + 1, 7);
    expect(await other.load(), isEmpty);
    await other.save([
      PendingChatMessage('other draft', 'other-id', draft.createdAt),
    ]);
    final restored = await login(account, 7);
    expect((await restored.load()).single.clientMsgId, 'pending-id');
    expect((await other.load()).single.clientMsgId, 'other-id');
  });

  test(
    'successful withdrawal API removes the old account outbox before clearing login',
    () async {
      final other = await login(account + 1, 7);
      await other.save([draft]);
      final withdrawn = await login(account, 7);
      await withdrawn.save([draft]);
      await http.runWithClient(
        () => AuthApiService.instance.withdraw(),
        () => MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(request.url.path, '/api/v1/users/me');
          return http.Response('', 204);
        }),
      );
      expect(auth.isLoggedIn.value, isFalse);
      expect(await withdrawn.load(), isEmpty);
      expect((await other.load()).single.clientMsgId, 'pending-id');
      await withdrawn.save([draft]);
      expect(await withdrawn.load(), isEmpty);
    },
  );

  test('rejected withdrawal preserves login and pending messages', () async {
    final store = await login(account, 7);
    await store.save([draft]);
    await expectLater(
      http.runWithClient(
        () => AuthApiService.instance.withdraw(),
        () => MockClient(
          (_) async => http.Response('{"message":"unavailable"}', 503),
        ),
      ),
      throwsA(isA<ApiException>()),
    );
    expect(auth.userId, account);
    expect((await store.load()).single.clientMsgId, 'pending-id');
  });
}
