import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/config/app_config.dart';

/// 서버 주소를 어디까지 받아 줄지 고정한다.
///
/// 원격 설정과 캐시에 담긴 주소는 앱 밖에서 정해진다. 그 값을 평문으로도
/// 받아 주면, 그 주소를 바꿀 수 있는 사람에게 로그인 토큰이 그대로 나간다.
/// 빌드할 때 박아 넣는 값은 빌드하는 사람이 정한 것이라 평문을 허용한다 —
/// 개발 중에는 컴퓨터에 띄운 서버를 봐야 한다.
void main() {
  test('원격·캐시 주소는 평문을 거른다', () {
    expect(AppConfig.debugNormalize('http://evil.example', requireHttps: true), isNull);
    expect(
      AppConfig.debugNormalize('https://api.example.com', requireHttps: true),
      'https://api.example.com',
    );
  });

  test('빌드에 박아 넣는 값은 평문도 받는다', () {
    expect(
      AppConfig.debugNormalize('http://10.0.2.2:8090'),
      'http://10.0.2.2:8090',
    );
  });

  test('스킴이 없거나 호스트가 비면 쓰지 않는다', () {
    expect(AppConfig.debugNormalize('api.example.com'), isNull);
    expect(AppConfig.debugNormalize('https://'), isNull);
    expect(AppConfig.debugNormalize('  '), isNull);
  });

  test('뒤 슬래시를 떼어 경로가 겹치지 않게 한다', () {
    // 호출부가 '$base/api/v1/...' 로 이어 붙이므로, 남아 있으면 //api/v1 이 된다.
    expect(AppConfig.debugNormalize('https://api.example.com/'), 'https://api.example.com');
  });
}
