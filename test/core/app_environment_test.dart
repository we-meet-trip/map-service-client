import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/config/app_environment.dart';

void main() {
  test('default test app cannot share the production native identity', () {
    expect(AppEnvironment.name, 'test');
    expect(AppEnvironment.applicationId, 'kr.mapservice.client.test');
    expect(AppEnvironment.kakaoScheme, 'mapauth-test');
    expect(AppEnvironment.inviteScheme, 'mapservice-test');
    expect(
      AppEnvironment.policyUrl('privacy.html').toString(),
      'https://mapcenter-b59ca.web.app/legal/privacy.html',
    );
  });

  test('policy links cannot escape the approved document set', () {
    for (final document in [
      '../secret',
      'https://other.example',
      'privacy.html?x=1',
    ]) {
      expect(() => AppEnvironment.policyUrl(document), throwsArgumentError);
    }
  });
}
