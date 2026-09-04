// 탈퇴가 로그아웃과 다르게 동작하는지 본다.
//
// 로그아웃은 서버 호출이 실패해도 기기의 토큰을 버린다 — 남겨 두면 로그아웃한
// 사람이 로그인 상태로 보이기 때문이다. 탈퇴는 그 반대다. 서버에 계정이 남아
// 있는데 기기만 비우면 사용자는 지워진 줄 알고 떠나고, 계정은 그대로 남는다.
// 그래서 실패는 반드시 화면까지 올라가야 한다.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:map_service_client/core/api/api_client.dart';
import 'package:map_service_client/core/api/auth_api_service.dart';
import 'package:map_service_client/core/state/auth_store.dart';

const _secureStorageChannel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // 보관소는 기기 저장소를 부른다. 시험에서는 부르기만 받아 준다.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  });

  test('내 계정 경로로 삭제를 보낸다', () async {
    String? seenMethod;
    String? seenPath;

    await http.runWithClient(
      () => AuthApiService.instance.withdraw(),
      () => MockClient((request) async {
        seenMethod = request.method;
        seenPath = request.url.path;
        return http.Response('', 204);
      }),
    );

    expect(seenMethod, 'DELETE');
    expect(seenPath, '/api/v1/users/me');
  });

  test('서버가 거절하면 오류를 올려보낸다 — 기기만 비우지 않는다', () async {
    await expectLater(
      http.runWithClient(
        () => AuthApiService.instance.withdraw(),
        () => MockClient((_) async => http.Response('', 500)),
      ),
      throwsA(isA<ApiException>()),
    );
  });

  test('삭제가 끝나면 로그인 상태가 풀린다', () async {
    AuthStore.instance.isLoggedIn.value = true;

    await http.runWithClient(
      () => AuthApiService.instance.withdraw(),
      () => MockClient((_) async => http.Response('', 204)),
    );

    expect(AuthStore.instance.isLoggedIn.value, isFalse);
  });
}
