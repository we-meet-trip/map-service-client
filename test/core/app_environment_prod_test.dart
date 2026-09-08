import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/config/app_environment.dart';
import 'package:map_service_client/core/services/deep_link_service.dart';

void main() {
  group('production build identity', () {
    test('uses production native IDs and rejects test custom links', () {
      expect(AppEnvironment.applicationId, 'kr.mapservice.client');
      expect(AppEnvironment.kakaoScheme, 'mapauth');
      expect(AppEnvironment.inviteScheme, 'mapservice');
      expect(
        DeepLinkService.routeOf(Uri.parse('mapservice://invite/TOK')),
        '/invite/TOK',
      );
      expect(
        DeepLinkService.routeOf(Uri.parse('mapservice-test://invite/TOK')),
        isNull,
      );
      expect(
        DeepLinkService.routeOf(
          Uri.parse('https://mapcenter-b59ca.web.app/invite/TOK'),
        ),
        isNull,
      );
    });

    test('missing production policy origin cannot fall back to test', () {
      expect(AppEnvironment.publicOrigin, isEmpty);
      expect(() => AppEnvironment.policyUrl('privacy.html'), throwsStateError);
    });
  }, skip: AppEnvironment.name != 'prod');
}
