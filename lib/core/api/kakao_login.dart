import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'api_client.dart';
import 'auth_api_service.dart';

/// 카카오 로그인.
///
/// 카카오톡이 깔려 있으면 카카오톡 앱으로 곧장 전환해 로그인한다. 이 경로에는
/// 브라우저가 한 구간도 끼지 않는다 — 카카오는 로그인이 진행되는 동안 접속 IP 가
/// 바뀌면 계정 탈취로 보고 끊는데, 브라우저를 거치면 그 브라우저와 카카오톡 앱이
/// 서로 다른 경로로 나가면서 IP 가 갈릴 수 있다(아이폰의 비공개 릴레이가 그렇다).
///
/// 카카오톡이 없으면 카카오계정 로그인으로 넘어간다. 이쪽은 브라우저를 쓰므로 위
/// 문제가 남아 있고, 그래서 실패했을 때 사용자가 무엇을 해 볼 수 있는지 알려 준다.
class KakaoLogin {
  KakaoLogin({
    Future<bool> Function()? talkInstalled,
    Future<OAuthToken> Function()? loginWithTalk,
    Future<OAuthToken> Function()? loginWithAccount,
    Future<void> Function(String)? exchange,
  }) : _talkInstalled = talkInstalled ?? isKakaoTalkInstalled,
       _loginWithTalk =
           loginWithTalk ?? (() => UserApi.instance.loginWithKakaoTalk()),
       _loginWithAccount =
           loginWithAccount ?? (() => UserApi.instance.loginWithKakaoAccount()),
       _exchange = exchange ?? AuthApiService.instance.kakaoLogin;

  static final KakaoLogin instance = KakaoLogin();

  final Future<bool> Function() _talkInstalled;
  final Future<OAuthToken> Function() _loginWithTalk;
  final Future<OAuthToken> Function() _loginWithAccount;
  final Future<void> Function(String) _exchange;

  static const _cancelled = ApiException(
    statusCode: 0,
    code: 'KAKAO_CANCELLED',
    message: '카카오 로그인이 취소되었어요.',
  );

  /// 브라우저를 거치는 경로에서만 나온다. 원인을 단정할 수는 없지만, 이 자리에서
  /// 사용자가 직접 해 볼 수 있는 조치는 비공개 릴레이 해제뿐이다.
  static const _browserBlocked = ApiException(
    statusCode: 0,
    code: 'KAKAO_BROWSER_BLOCKED',
    message:
        '카카오 로그인을 마치지 못했어요. 설정 > Apple 계정 > iCloud > 비공개 릴레이를 끄고 '
        '다시 시도해주세요.',
  );

  Future<void> run() async {
    final token = await _authorize();
    await _exchange(token.accessToken);
  }

  Future<OAuthToken> _authorize() async {
    if (await _talkInstalled()) {
      try {
        return await _loginWithTalk();
      } catch (error) {
        // 사용자가 스스로 그만둔 것은 다시 시도할 일이 아니다.
        if (_isCancellation(error)) throw _cancelled;
      }
    }
    try {
      return await _loginWithAccount();
    } catch (error) {
      if (_isCancellation(error)) throw _cancelled;
      throw _browserBlocked;
    }
  }

  static bool _isCancellation(Object error) =>
      error is PlatformException && error.code == 'CANCELED';
}
