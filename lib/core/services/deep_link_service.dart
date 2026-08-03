import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';

class DeepLinkService {
  DeepLinkService._();

  static final _appLinks = AppLinks();

  static Future<void> init(GoRouter router) async {
    // 앱을 연 주소를 묻는 일은 기기에서만 성립한다. 브라우저에는 그것을
    // 대신할 수단이 없어 물어보는 순간 실패로 끝나는데, 아무도 받지 않는
    // 실패라 조용히 흘러 나가 다른 진짜 오류를 가린다.
    //
    // 브라우저에서 초대 링크를 여는 길은 따로 만들어야 한다(현재 화면 주소는
    // 자리표시 방식이라 경로가 잡히지 않는다). 그때까지는 건너뛴다.
    if (kIsWeb) return;

    final initial = await _appLinks.getInitialLink();
    if (initial != null) _route(initial, router);

    _appLinks.uriLinkStream.listen((uri) => _route(uri, router));
  }

  static void _route(Uri uri, GoRouter router) {
    String? token;

    // HTTPS App Link: https://domain.com/invite/TOKEN
    if ((uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments[0] == 'invite') {
      token = uri.pathSegments[1];
    }
    // 앱 전용 주소: mapservice://invite/TOKEN
    // 웹 주소가 확정되기 전까지 실제로 열리는 경로는 이쪽뿐이다.
    else if (uri.scheme == 'mapservice' &&
        uri.host == 'invite' &&
        uri.pathSegments.isNotEmpty) {
      token = uri.pathSegments[0];
    }

    if (token != null && token.isNotEmpty) {
      router.go('/invite/$token');
    }
  }
}
