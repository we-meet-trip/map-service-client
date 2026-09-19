import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:map_service_client/core/api/api_client.dart';
import 'package:map_service_client/core/api/kakao_login.dart';

/// 카카오 로그인이 어느 경로를 쓰는지가 이 기능의 전부다.
///
/// 카카오톡 앱으로 곧장 전환하는 경로에는 브라우저가 끼지 않아서, 로그인 도중
/// 접속 IP 가 갈릴 일이 없다. 브라우저를 쓰는 경로는 그 위험이 남으므로 마지막
/// 수단으로만 쓰이고, 거기서 실패하면 사용자가 해 볼 수 있는 조치를 알려 준다.
void main() {
  OAuthToken token(String value) =>
      OAuthToken(value, DateTime(2030), null, null, null);

  ({List<String> calls, List<String> sent, KakaoLogin login}) build({
    required bool installed,
    Object? talkFails,
    Object? accountFails,
  }) {
    final calls = <String>[];
    final sent = <String>[];
    final login = KakaoLogin(
      talkInstalled: () async {
        calls.add('installed?');
        return installed;
      },
      loginWithTalk: () async {
        calls.add('talk');
        if (talkFails != null) throw talkFails;
        return token('talk-token');
      },
      loginWithAccount: () async {
        calls.add('account');
        if (accountFails != null) throw accountFails;
        return token('account-token');
      },
      exchange: (accessToken) async => sent.add(accessToken),
    );
    return (calls: calls, sent: sent, login: login);
  }

  String codeOf(Object error) => (error as ApiException).code;

  test('카카오톡이 있으면 브라우저를 열지 않고 그 토큰을 서버로 넘긴다', () async {
    final it = build(installed: true);
    await it.login.run();
    expect(it.calls, ['installed?', 'talk']);
    expect(it.calls, isNot(contains('account')));
    expect(it.sent, ['talk-token']);
  });

  test('카카오톡이 없으면 브라우저 경로로 넘어간다', () async {
    final it = build(installed: false);
    await it.login.run();
    expect(it.calls, ['installed?', 'account']);
    expect(it.sent, ['account-token']);
  });

  test('카카오톡 전환이 실패하면 브라우저 경로로 이어 간다', () async {
    final it = build(installed: true, talkFails: StateError('카카오톡 없음'));
    await it.login.run();
    expect(it.calls, ['installed?', 'talk', 'account']);
    expect(it.sent, ['account-token']);
  });

  test('사용자가 그만둔 것은 다시 시도하지 않는다', () async {
    final it = build(
      installed: true,
      talkFails: PlatformException(code: 'CANCELED'),
    );
    await expectLater(
      it.login.run(),
      throwsA(predicate<Object>((e) => codeOf(e) == 'KAKAO_CANCELLED')),
    );
    expect(it.calls, isNot(contains('account')));
    expect(it.sent, isEmpty);
  });

  test('브라우저 경로에서 취소해도 실패 안내로 바뀌지 않는다', () async {
    final it = build(
      installed: false,
      accountFails: PlatformException(code: 'CANCELED'),
    );
    await expectLater(
      it.login.run(),
      throwsA(predicate<Object>((e) => codeOf(e) == 'KAKAO_CANCELLED')),
    );
    expect(it.sent, isEmpty);
  });

  test('브라우저 경로가 막히면 무엇을 해 볼지 알려 준다', () async {
    final it = build(installed: false, accountFails: StateError('거절'));
    await expectLater(
      it.login.run(),
      throwsA(
        predicate<Object>(
          (e) =>
              codeOf(e) == 'KAKAO_BROWSER_BLOCKED' &&
              (e as ApiException).message.contains('비공개 릴레이'),
        ),
      ),
    );
    expect(it.sent, isEmpty);
  });
}
