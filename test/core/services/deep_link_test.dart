import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/services/deep_link_service.dart';

/// 링크가 앱을 여는 길은 셋(웹 주소·앱 전용 주소·그 외)이고, 셋 중 어느 것도
/// 조용히 무시되면 안 된다. 무시되면 링크를 눌러도 아무 일이 없는 것처럼 보인다.
void main() {
  test('웹 주소는 토큰을 뽑아낸다', () {
    expect(
      DeepLinkService.routeOf(Uri.parse('https://mapcenter-b59ca.web.app/invite/TOK')),
      '/invite/TOK',
    );
  });

  test('앱 전용 주소도 같은 화면으로 간다', () {
    expect(
      DeepLinkService.routeOf(Uri.parse('mapservice://invite/TOK')),
      '/invite/TOK',
    );
  });

  test('예전 스킴은 더 이상 받지 않는다', () {
    // 세 곳이 서로 다른 이름을 쓰던 것을 하나로 모았다.
    expect(DeepLinkService.routeOf(Uri.parse('wemeettrip://invite/TOK')), isNull);
  });

  test('초대와 무관한 주소는 넘기지 않는다', () {
    expect(DeepLinkService.routeOf(Uri.parse('https://example.invalid/other/TOK')), isNull);
    expect(DeepLinkService.routeOf(Uri.parse('mapauth://kakao')), isNull);
    expect(DeepLinkService.routeOf(Uri.parse('mapservice://invite')), isNull);
  });
}
