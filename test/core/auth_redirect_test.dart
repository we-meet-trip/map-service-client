import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/router/app_router.dart';

/// 로그인 관문이 무엇을 막고 무엇을 여는지 고정한다.
///
/// 초대가 열려 있는지가 특히 중요하다. 초대 화면은 로그인이 안 되어 있으면
/// 받은 토큰을 스스로 보관해 두고 로그인으로 보낸 뒤 끝나면 그 방으로
/// 데려가는데, 관문이 그 화면보다 먼저 돌려보내면 링크에 실려 온 토큰이
/// 사라진다. 링크를 실제로 눌러 보기 전에는 드러나지 않는 종류라 여기서 막는다.
void main() {
  test('로그인 전에도 초대 링크는 그대로 열린다', () {
    expect(authRedirect(authed: false, location: '/invite/abc123'), isNull);
  });

  test('로그인 전 보호된 자리는 로그인으로 보낸다', () {
    expect(authRedirect(authed: false, location: '/saved'), '/auth');
    expect(authRedirect(authed: false, location: '/trip'), '/auth');
    expect(authRedirect(authed: false, location: '/chat/7'), '/auth');
  });

  test('로그인 전에 열려 있어야 하는 자리는 그대로 둔다', () {
    for (final loc in ['/splash', '/auth', '/auth/email', '/signup/step1']) {
      expect(authRedirect(authed: false, location: loc), isNull, reason: loc);
    }
  });

  test('로그인했으면 어디로도 보내지 않는다', () {
    expect(authRedirect(authed: true, location: '/saved'), isNull);
    expect(authRedirect(authed: true, location: '/auth'), isNull);
  });
}
