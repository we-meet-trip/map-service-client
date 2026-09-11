import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/router/app_router.dart';

/// 관문이 무엇을 막고 무엇을 여는지 고정한다. 권한 고지 관문이 먼저,
/// 로그인 관문이 다음이다.
///
/// 초대가 열려 있는지가 특히 중요하다. 초대 화면은 로그인이 안 되어 있으면
/// 받은 토큰을 스스로 보관해 두고 로그인으로 보낸 뒤 끝나면 그 방으로
/// 데려가는데, 관문이 그 화면보다 먼저 돌려보내면 링크에 실려 온 토큰이
/// 사라진다. 링크를 실제로 눌러 보기 전에는 드러나지 않는 종류라 여기서 막는다.
void main() {
  test('로그인 전에도 초대 링크는 그대로 열린다', () {
    expect(
      authRedirect(authed: false, noticeSeen: true, location: '/invite/abc123'),
      isNull,
    );
  });

  test('로그인 전 보호된 자리는 로그인으로 보낸다', () {
    for (final loc in ['/saved', '/trip', '/chat/7']) {
      expect(
        authRedirect(authed: false, noticeSeen: true, location: loc),
        '/auth',
        reason: loc,
      );
    }
  });

  test('로그인 전에 열려 있어야 하는 자리는 그대로 둔다', () {
    for (final loc in ['/splash', '/auth', '/auth/email', '/signup/step1']) {
      expect(
        authRedirect(authed: false, noticeSeen: true, location: loc),
        isNull,
        reason: loc,
      );
    }
  });

  test('로그인 후 서비스 동의를 요구하고 인증 화면은 유지한다', () {
    expect(
      authRedirect(authed: true, noticeSeen: true, location: '/saved'),
      '/service-consent',
    );
    expect(
      authRedirect(authed: true, noticeSeen: true, location: '/auth'),
      isNull,
    );
  });

  test('고지를 아직 안 봤으면 고지 화면으로 보낸다', () {
    expect(
      authRedirect(authed: true, noticeSeen: false, location: '/'),
      '/permission-notice',
    );
    expect(
      authRedirect(authed: false, noticeSeen: false, location: '/auth'),
      '/permission-notice',
    );
  });

  test('고지 전에도 스플래시·고지·초대는 그대로 둔다', () {
    for (final loc in ['/splash', '/permission-notice', '/invite/abc']) {
      expect(
        authRedirect(authed: false, noticeSeen: false, location: loc),
        isNull,
        reason: loc,
      );
    }
  });

  test('고지를 봤으면 로그인과 서비스 동의를 판정한다', () {
    expect(
      authRedirect(authed: false, noticeSeen: true, location: '/'),
      '/auth',
    );
    expect(
      authRedirect(authed: true, noticeSeen: true, location: '/'),
      '/service-consent',
    );
  });

  test('서버 동의 확인 후에만 모든 보호 경로에 들어간다', () {
    for (final location in [
      '/vision',
      '/google-map',
      '/invite/token',
      '/navigation',
      '/bike-scooter',
      '/trip/research',
      '/saved',
      '/chat/7',
      '/mypage',
      '/address-search',
    ]) {
      expect(
        authRedirect(authed: true, noticeSeen: true, location: location),
        '/service-consent',
        reason: location,
      );
      expect(
        authRedirect(
          authed: true,
          noticeSeen: true,
          location: location,
          policyAccepted: true,
        ),
        isNull,
        reason: location,
      );
    }
  });

  test('미동의 계정의 정정 및 탈퇴 전용 화면은 허용한다', () {
    for (final location in ['/service-consent', '/service-consent/profile']) {
      expect(
        authRedirect(authed: true, noticeSeen: true, location: location),
        isNull,
      );
      expect(
        authRedirect(authed: false, noticeSeen: true, location: location),
        '/auth',
      );
    }
  });
}
