import 'package:app_links/app_links.dart';
import 'package:go_router/go_router.dart';

class DeepLinkService {
  DeepLinkService._();

  static final _appLinks = AppLinks();

  static Future<void> init(GoRouter router) async {
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
