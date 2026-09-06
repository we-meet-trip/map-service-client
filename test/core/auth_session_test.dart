import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:map_service_client/core/api/api_client.dart';
import 'package:map_service_client/core/api/auth_api_service.dart';
import 'package:map_service_client/core/state/auth_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final values = <String, String>{};
  final auth = AuthStore.instance;
  const a = AuthTokens(accessToken: 'a', refreshToken: 'ra', userId: 1);
  const b = AuthTokens(accessToken: 'b', refreshToken: 'rb', userId: 2);

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final key = call.arguments['key'] as String;
          switch (call.method) {
            case 'read':
              return values[key];
            case 'write':
              values[key] = call.arguments['value'] as String;
            case 'delete':
              values.remove(key);
          }
          return null;
        });
    await auth.clear();
    values.clear();
    auth.refreshHandler = null;
  });

  test('logout sends both access and refresh token', () async {
    await auth.save(a);
    await http.runWithClient(
      () => AuthApiService.instance.logout(),
      () => MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer a');
        expect(jsonDecode(request.body)['refreshToken'], 'ra');
        return http.Response('', 204);
      }),
    );
    expect(auth.accessToken, isNull);
    expect(values, isEmpty);
  });

  test('late successful refresh cannot restore a logged out session', () async {
    await auth.save(a);
    final response = Completer<AuthTokens?>();
    auth.refreshHandler = (_) => response.future;
    final pending = auth.refresh();
    await auth.clear();
    response.complete(a);
    expect(await pending, isFalse);
    expect(auth.isLoggedIn.value, isFalse);
    expect(values, isEmpty);
  });

  test('old refresh failure cannot clear a different account', () async {
    await auth.save(a);
    final response = Completer<AuthTokens?>();
    auth.refreshHandler = (_) => response.future;
    final pending = auth.refresh();
    await auth.save(b);
    response.complete(null);
    expect(await pending, isFalse);
    expect(auth.accessToken, 'b');
    await auth.restore();
    expect(auth.userId, 2);
  });

  test('parallel refresh shares one request', () async {
    await auth.save(a);
    var calls = 0;
    final response = Completer<AuthTokens?>();
    auth.refreshHandler = (_) {
      calls++;
      return response.future;
    };
    final first = auth.refresh();
    final second = auth.refresh();
    response.complete(a);
    expect(await Future.wait([first, second]), [true, true]);
    expect(calls, 1);
  });

  test('late protected response does not enter a new account', () async {
    await auth.save(a);
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final pending = http.runWithClient(
      () => ApiClient.instance.get('/api/v1/users/me'),
      () => MockClient((_) {
        started.complete();
        return response.future;
      }),
    );
    final checked = expectLater(
      pending,
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'SESSION_CHANGED'),
      ),
    );
    await started.future;
    await auth.save(b);
    response.complete(http.Response('{"nickname":"account A"}', 200));
    await checked;
    expect(auth.userId, 2);
  });
}
