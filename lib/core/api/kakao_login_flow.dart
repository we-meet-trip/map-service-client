import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_client.dart';
import 'auth_api_service.dart';

/// 카카오 로그인 한 판.
///
/// 흐름:
///   1) 서버에서 카카오 인가 화면 주소를 받는다.
///   2) 기기 브라우저로 그 주소를 연다(앱 안 웹뷰가 아니라 브라우저를 쓴다 —
///      카카오가 이미 로그인해 둔 세션을 그대로 쓸 수 있다).
///   3) 카카오가 서버 콜백으로 보내고, 서버가 앱 주소로 되돌려보낸다.
///   4) 되돌아온 주소에서 인가 코드를 꺼내 서버에 넘겨 토큰으로 바꾼다.
///
/// 되돌아온 주소의 state 가 내가 보낸 것과 다르면 버린다. 내가 시작하지
/// 않은 로그인을 받아들이면 남의 계정으로 들어가게 된다.
class KakaoLoginFlow {
  KakaoLoginFlow._();
  static final KakaoLoginFlow instance = KakaoLoginFlow._();

  /// 서버가 되돌려보내는 앱 주소의 체계. 서버 설정과 같아야 한다.
  static const _callbackScheme = 'mapauth';

  /// 브라우저에서 돌아오지 않는 상태로 영원히 기다리지 않도록 두는 상한.
  static const _timeout = Duration(minutes: 3);

  final _appLinks = AppLinks();

  /// 로그인을 끝까지 진행한다. 성공하면 토큰이 보관소에 들어간다.
  ///
  /// state: 이번 요청을 가리키는 값. 호출 측이 매번 다른 값을 준다.
  Future<void> run(String state) async {
    final url = await AuthApiService.instance.kakaoAuthorizeUrl(state);

    // 브라우저에서 돌아오는 주소를 먼저 듣기 시작한다. 브라우저를 연 뒤에
    // 듣기 시작하면 그 사이에 돌아온 주소를 놓친다.
    final returned = _awaitCallback(state);

    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      throw const ApiException(
        statusCode: 0,
        code: 'BROWSER_UNAVAILABLE',
        message: '브라우저를 열지 못했어요.',
      );
    }

    final code = await returned;
    await AuthApiService.instance.kakaoLogin(code);
  }

  /// 앱으로 되돌아온 주소에서 인가 코드를 꺼낸다.
  Future<String> _awaitCallback(String state) async {
    final completer = Completer<String>();
    late final StreamSubscription<Uri> sub;

    void finish(String code) {
      if (!completer.isCompleted) completer.complete(code);
    }

    void fail(ApiException e) {
      if (!completer.isCompleted) completer.completeError(e);
    }

    sub = _appLinks.uriLinkStream.listen((uri) {
      if (uri.scheme != _callbackScheme) return;
      if (uri.queryParameters['state'] != state) {
        // 내가 시작하지 않은 복귀다. 조용히 무시하고 계속 기다린다.
        return;
      }
      final error = uri.queryParameters['error'];
      if (error != null && error.isNotEmpty) {
        fail(ApiException(
          statusCode: 0,
          code: error,
          message: uri.queryParameters['error_description'] ??
              '카카오 로그인이 취소되었어요.',
        ));
        return;
      }
      final code = uri.queryParameters['code'];
      if (code == null || code.isEmpty) {
        fail(const ApiException(
          statusCode: 0,
          code: 'KAKAO_NO_CODE',
          message: '카카오에서 인가 정보를 받지 못했어요.',
        ));
        return;
      }
      finish(code);
    });

    try {
      return await completer.future.timeout(
        _timeout,
        onTimeout: () => throw const ApiException(
          statusCode: 0,
          code: 'KAKAO_TIMEOUT',
          message: '로그인이 완료되지 않았어요. 다시 시도해주세요.',
        ),
      );
    } finally {
      await sub.cancel();
    }
  }
}
