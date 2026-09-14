import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:map_service_client/core/api/api_client.dart';
import 'package:map_service_client/core/api/kakao_login_flow.dart';
import 'package:map_service_client/core/state/auth_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final auth = AuthStore.instance;
  final stored = <String, String>{};

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final key = call.arguments['key'] as String;
          switch (call.method) {
            case 'read':
              return stored[key];
            case 'write':
              stored[key] = call.arguments['value'] as String;
            case 'delete':
              stored.remove(key);
          }
          return null;
        });
    await auth.clear();
    stored.clear();
  });

  test('late Kakao token exchange cannot overwrite a newer account', () async {
    final links = StreamController<Uri>.broadcast(sync: true);
    addTearDown(links.close);
    final launched = Completer<void>();
    final requested = Completer<void>();
    final response = Completer<http.Response>();
    final flow = KakaoLoginFlow(
      authorizeUrl: (_) async => 'https://kauth.kakao.com/oauth/authorize',
      launch: (_) async {
        launched.complete();
        return true;
      },
      callbacks: () => links.stream,
    );
    final pending = http.runWithClient(
      () => flow.run('state'),
      () => MockClient((request) {
        expect(request.url.path, '/api/v1/auth/kakao/callback');
        expect(jsonDecode(request.body), {'code': 'old-code'});
        requested.complete();
        return response.future;
      }),
    );
    final checked = expectLater(
      pending,
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'SESSION_CHANGED'),
      ),
    );
    await launched.future;
    links.add(Uri.parse('mapauth-test://kakao?state=state&code=old-code'));
    await requested.future;
    await auth.save(
      const AuthTokens(
        accessToken: 'new-account',
        refreshToken: 'new-refresh',
        userId: 2,
      ),
    );
    response.complete(
      http.Response(
        jsonEncode({
          'accessToken': 'old-account',
          'refreshToken': 'old-refresh',
          'user': {'id': 1, 'nickname': 'old'},
        }),
        200,
      ),
    );
    await checked;
    expect(auth.userId, 2);
    expect(auth.accessToken, 'new-account');
    expect(links.hasListener, isFalse);
    await auth.restore();
    expect(auth.userId, 2);
    expect(auth.accessToken, 'new-account');
  });

  test('브라우저에서 콜백 없이 돌아오면 취소로 기다림을 끝낸다', () async {
    final links = StreamController<Uri>.broadcast(sync: true);
    addTearDown(links.close);
    final launched = Completer<void>();
    final flow = KakaoLoginFlow(
      authorizeUrl: (_) async => 'https://kauth.kakao.com/oauth/authorize',
      launch: (_) async {
        launched.complete();
        return true;
      },
      callbacks: () => links.stream,
      exchange: (_) async => fail('취소했는데 인가 코드를 교환했다'),
    );

    final pending = flow.run('state');
    await launched.future;

    expect(flow.cancel(), isTrue);
    await expectLater(
      pending,
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'KAKAO_CANCELLED'),
      ),
    );

    // 기다리는 것이 없으면 아무 일도 하지 않는다.
    expect(flow.cancel(), isFalse);
  });
}
