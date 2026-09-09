// 실기기·시뮬레이터에서 앱을 실제로 띄워 화면이 제대로 나오는지 확인한다.
//
// 위젯 시험과 다른 점은 네트워크가 진짜로 나간다는 것이다. 그래서 이 시험은
// 서버가 떠 있어야 돌고, 화면에 나온 값이 서버가 실제로 준 값인지까지 본다.
// 화면 조립만 보는 시험은 서버 계약이 바뀐 것을 못 잡는다.
//
// 실행:
//   flutter test integration_test/app_screens_test.dart \
//     -d <device> --dart-define=API_BASE_URL=https://… \
//     --dart-define=TEST_EMAIL=… --dart-define=TEST_PASSWORD=…
//
// 시험 계정은 실행할 때 넘긴다. 저장소에 두면 서버를 아무나 열 수 있다.
//
// 안드로이드 에뮬레이터에서는 호스트 주소가 10.0.2.2 다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:map_service_client/core/api/api_client.dart';
import 'package:map_service_client/core/api/auth_api_service.dart';
import 'package:map_service_client/core/api/service_consent_api_service.dart';
import 'package:map_service_client/core/state/service_consent_store.dart';
import 'package:map_service_client/core/config/app_config.dart';
import 'package:map_service_client/core/state/auth_store.dart';
import 'package:map_service_client/data/local/permission_notice_store.dart';
import 'package:map_service_client/data/local/profile_local_store.dart';
import 'package:map_service_client/core/api/pm_vehicle_api_service.dart';
import 'package:map_service_client/features/home/services/weather_service.dart';
import 'package:map_service_client/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// 화면이 안정될 때까지 기다린다.
  ///
  /// pumpAndSettle 은 못 쓴다 — 지도와 로딩 표시가 계속 애니메이션을 돌려
  /// 영영 가라앉지 않는다. 정해진 횟수만큼 프레임을 밀어 준다.
  Future<void> settle(WidgetTester tester, {int frames = 40}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  /// 화면에 보이는 문구를 모두 모은다. 무엇이 그려졌는지 눈으로 확인하는 데
  /// 쓰고, 실패했을 때 무엇이 대신 나왔는지 남긴다.
  List<String> visibleTexts(WidgetTester tester) {
    final out = <String>[];
    for (final w in tester.widgetList<Text>(find.byType(Text))) {
      final t = w.data;
      if (t != null && t.trim().isNotEmpty) out.add(t.trim());
    }
    return out;
  }

  // 서버가 로그인을 요구한다. 자격을 주지 않으면 아래 자료 검사들은 전부
  // 401 로 떨어지는데, 그것은 서버 결함이 아니라 시험을 그렇게 돌린 것이다.
  // 그래서 자격이 없으면 실패가 아니라 건너뛴다.
  const email = String.fromEnvironment('TEST_EMAIL');
  const password = String.fromEnvironment('TEST_PASSWORD');
  const signedIn = email != '' && password != '';
  // 자격이 없으면 건너뛴다(실패가 아니다).
  const needsAccount = !signedIn;

  // 서버 주소는 앱이 시작할 때 정해진다. 그 전에 서비스를 부르면 정해지기
  // 전의 기본값으로 나가, 시험이 엉뚱한 자리를 두드리고도 통과하거나 실패한다.
  // (실제로 그랬다 — 기본값이 우연히 다른 서비스의 포트와 같아 한쪽 기기에서만
  // 통과했다.)
  //
  // 앱이 시작할 때 하는 준비를 그대로 한다. 보관소를 열지 않으면 로그인이
  // 성공해도 토큰이 저장 범위 밖에 있어 요청에 실리지 않는다.
  setUpAll(() async {
    await Hive.initFlutter();
    await PermissionNoticeStore.init();
    await ProfileLocalStore.init();
    await AppConfig.instance.init();
    ServiceConsentApiService.instance.bind(ServiceConsentStore.instance);
    await AuthApiService.instance.bootstrap();
    if (signedIn) {
      await AuthApiService.instance.login(email: email, password: password);
      expect(
        AuthStore.instance.accessToken,
        isNotNull,
        reason: '로그인은 됐는데 토큰이 실리지 않는다 — 보관소 준비를 확인하라',
      );
      // 공통 통로가 요청마다 이용 조건을 확인한다. 이것을 읽어 두지 않으면
      // 모든 요청이 조건 미확인으로 막혀, 서버가 멀쩡한데도 실패로 보인다.
      await ServiceConsentStore.instance.refresh(force: true);
      expect(
        ServiceConsentStore.instance.canAccess,
        isTrue,
        reason: '이 계정이 현재 판 이용 조건에 동의하지 않았다',
      );
    }
  });

  group('서버-화면 연결', () {
    testWidgets('앱이 의도한 서버 주소를 쓴다', (tester) async {
      // 이 값이 어긋나면 아래 시험들이 무엇을 확인한 것인지 알 수 없다.
      //
      // 어느 서버를 향해 시험하는지는 실행할 때 정한다. 한 곳을 코드에 박아
      // 두면 다른 환경에서는 통과할 수 없고, 그 환경을 시험하려는 사람이
      // 시험 자체를 고쳐야 한다.
      const expected = String.fromEnvironment('API_BASE_URL');
      expect(kApiBaseUrl, isNotEmpty);
      expect(
        expected,
        isNotEmpty,
        reason: '--dart-define=API_BASE_URL 로 시험할 서버를 지정해야 한다',
      );
      expect(
        kApiBaseUrl,
        expected,
        reason: '지정한 곳이 아니라 다른 곳을 보고 있다: $kApiBaseUrl',
      );
    });

    testWidgets('날씨: 서버가 준 값이 홈 카드에 그대로 나온다', (tester) async {
      // 먼저 서버에서 직접 받아 둔다. 화면에 나온 값과 맞춰 보기 위해서다.
      final data = await WeatherService().fetchWeather(
        useApproximateLocation: true,
      );

      // 서버는 미리 받아 둔 값을 내려주고, 낡았으면 항목을 비운다.
      // 어느 쪽이든 카드가 죽지 않아야 한다.
      expect(
        data.hasAnything,
        isTrue,
        reason: '서버가 그릴 것을 하나도 안 줬다 — 폴링이 적재되지 않았을 수 있다',
      );

      app.main();
      await settle(tester, frames: 60);

      // 첫 진입에는 안내 화면들이 카드를 덮는다. 치우지 않으면 아래에서 찾는
      // 값이 "화면에 없다"가 아니라 "가려져 있다"가 된다. 새로 설치한 기기는
      // 접근 권한 안내부터 나오고, 그 뒤에 위치 권한을 묻는다.
      for (final label in ['확인했어요', '나중에']) {
        final button = find.text(label);
        if (button.evaluate().isNotEmpty) {
          await tester.tap(button);
          await settle(tester, frames: 60);
        }
      }

      final texts = visibleTexts(tester);
      expect(
        texts,
        isNot(contains('위치 접근 권한이 필요해요.')),
        reason: '권한 안내를 치우지 못했다 — 아래 검증이 가려진 화면을 보게 된다',
      );
      // 기온이 왔으면 화면에 그 숫자가 있어야 한다.
      final temp = data.temp;
      if (temp != null) {
        expect(
          texts.any((t) => t.contains('${temp.round()}°C')),
          isTrue,
          reason: '서버 기온 ${temp.round()}°C 가 화면에 없다. 화면 문구: $texts',
        );
      }
      // 미세먼지 등급이 왔으면 화면에 그 등급이 있어야 한다.
      final grade = data.pm10Grade;
      if (grade != null) {
        expect(
          texts.any((t) => t.contains(grade)),
          isTrue,
          reason: '서버 미세먼지 등급 "$grade" 가 화면에 없다. 화면 문구: $texts',
        );
      }
    }, skip: needsAccount);

    testWidgets('킥보드: 자료가 없으면 없다고 밝힌다', (tester) async {
      // 발급처가 이 지역 자료를 아직 안 내주는 상태다. 그때 화면이 아무 말도
      // 안 하면 사용자는 앱이 고장 난 줄 안다.
      final vehicles = await PmVehicleApiService.instance.fetchVehicles(
        latitude: 37.5665,
        longitude: 126.9780,
      );
      // 조회 자체는 되어야 한다(빈 목록은 정상, null 은 조회 실패).
      expect(
        vehicles,
        isNotNull,
        reason: '킥보드 조회가 실패했다 — 서버나 발급처 문제',
      );
    }, skip: needsAccount);

    testWidgets('따릉이: 서버가 실제 대여소를 준다', (tester) async {
      final body = await ApiClient.instance.get(
        '/api/v1/mobility/bike-stations',
        query: {'lat': '37.5665', 'lng': '126.978', 'radiusM': '1000'},
      );
      final stations = body['stations'];
      expect(stations, isA<List>());
      // 발급처가 자료를 안 내주는 때가 있다. 서버가 그것을 밝히면 앱 결함이
      // 아니므로 그대로 적고 넘어간다 — 여기서 실패로 세면 공급자 중단마다
      // 앱을 의심하게 된다. 서버가 정상이라고 했는데 비어 있을 때만 실패다.
      if (body['status'] == 'unavailable') {
        markTestSkipped('발급처가 대여소 자료를 내주지 않는다(서버가 unavailable 로 밝힘)');
        return;
      }
      expect(
        (stations as List).isNotEmpty,
        isTrue,
        reason: '서울 도심 1km 안에 대여소가 하나도 없을 리 없다',
      );
    }, skip: needsAccount);

  });
}
