import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/services/deep_link_service.dart';

/// 링크가 앱을 여는 길은 셋(웹 주소·앱 전용 주소·그 외)이고, 셋 중 어느 것도
/// 조용히 무시되면 안 된다. 무시되면 링크를 눌러도 아무 일이 없는 것처럼 보인다.
void main() {
  test('웹 주소는 토큰을 뽑아낸다', () {
    expect(
      DeepLinkService.routeOf(
        Uri.parse('https://mapcenter-b59ca.web.app/invite/TOK'),
      ),
      '/invite/TOK',
    );
  });

  test('앱 전용 주소도 같은 화면으로 간다', () {
    expect(
      DeepLinkService.routeOf(Uri.parse('mapservice-test://invite/TOK')),
      '/invite/TOK',
    );
  });

  test('예전 스킴은 더 이상 받지 않는다', () {
    // 세 곳이 서로 다른 이름을 쓰던 것을 하나로 모았다.
    expect(
      DeepLinkService.routeOf(Uri.parse('wemeettrip://invite/TOK')),
      isNull,
    );
  });

  test('초대와 무관한 주소는 넘기지 않는다', () {
    expect(
      DeepLinkService.routeOf(Uri.parse('https://example.invalid/other/TOK')),
      isNull,
    );
    expect(DeepLinkService.routeOf(Uri.parse('mapauth-test://kakao')), isNull);
    expect(
      DeepLinkService.routeOf(Uri.parse('mapservice-test://invite')),
      isNull,
    );
  });
  test('다른 환경·평문·경로 삽입 링크는 받지 않는다', () {
    for (final link in [
      'https://example.invalid/invite/TOK',
      'mapservice://invite/TOK',
      'http://mapcenter-b59ca.web.app/invite/TOK',
      'https://mapcenter-b59ca.web.app:8443/invite/TOK',
      'https://user@mapcenter-b59ca.web.app/invite/TOK',
      'https://mapcenter-b59ca.web.app/invite/TOK/extra',
      'https://mapcenter-b59ca.web.app/invite/TOK?redirect=x',
      'https://mapcenter-b59ca.web.app/invite/TOK#fragment',
      'mapservice-test://invite/TOK/extra',
      'mapservice-test://invite:443/TOK',
      'mapservice-test://invite/a%2Fb',
      'mapservice-test://invite/a%3Fb',
      'mapservice-test://invite/TOK?environment=prod',
    ]) {
      expect(DeepLinkService.routeOf(Uri.parse(link)), isNull, reason: link);
    }
  });
}
