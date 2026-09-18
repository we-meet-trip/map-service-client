// 저장된 일정을 열면 그것이 '지금 보고 있는 일정'이 되는지 본다.
//
// 이 화면 아래 '추가 탐색하기'는 장소 탐색 지도로 이어지는데, 그 지도는 화면이
// 들고 있는 목록이 아니라 보관해 둔 마지막 일정을 읽는다. 저장 탭에서 연 일정이
// 그 자리에 들어가지 않으면 탐색 지도가 이전에 만들던 다른 일정의 장소를 보여
// 준다 — 같은 장소를 눌러도 두 화면이 서로 다른 일정을 말하게 된다.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/maps/map_bootstrap.dart';
import 'package:map_service_client/core/state/trip_repository.dart';
import 'package:map_service_client/features/trip/screens/trip_created_screen.dart';

import 'google_map_screen_test.dart' show stop;

SavedTrip _saved({
  required String placeName,
  String? province = '강원특별자치도',
  String? city = '춘천시',
  String? transport = 'TRANSIT',
  int? startHour = 9,
  int? endHour = 21,
  int? scheduleId = 7,
}) => SavedTrip(
  scheduleId: scheduleId,
  name: '저장된 일정',
  route: '',
  savedAt: DateTime(2026, 1, 1),
  tripStartDate: DateTime(2026, 1, 1),
  tripEndDate: DateTime(2026, 1, 2),
  stops: [stop(placeName)],
  totalDurationMinutes: 60,
  province: province,
  city: city,
  transport: transport,
  activeStartHour: startHour,
  activeEndHour: endHour,
);

Future<void> _open(WidgetTester tester, SavedTrip trip) async {
  await tester.binding.setSurfaceSize(const Size(320, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  // 일정마다 다른 열쇠를 준다. 실제로는 일정을 열 때마다 화면이 새로 만들어
  // 지는데, 검사에서 같은 자리에 같은 종류를 다시 걸면 상태가 재사용돼 여는
  // 동작 자체가 일어나지 않는다.
  await tester.pumpWidget(
    MaterialApp(
      key: ValueKey(trip.scheduleId),
      home: Scaffold(body: TripCreatedScreen(savedTrip: trip)),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    mapsReady.value = false;
    TripRepository.instance.lastPlan = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geolocator'),
      (_) async => 1,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('hemanthraj/flutter_compass'),
      (_) async => null,
    );
  });

  testWidgets('저장된 일정을 열면 탐색이 그 일정을 보게 된다', (tester) async {
    await _open(tester, _saved(placeName: '소양강스카이워크'));

    final plan = TripRepository.instance.lastPlan;
    expect(plan, isNotNull);
    expect(plan!.stops.single.name, '소양강스카이워크');
    expect(plan.province, '강원특별자치도');
    expect(plan.transport, 'TRANSIT');
    // 저장된 일정에는 추천 식별자가 없어 같은 조건 재탐색은 걸 수 없다.
    expect(plan.canResearch, isFalse);
  });

  testWidgets('다른 일정을 열면 앞의 것이 남지 않는다', (tester) async {
    await _open(tester, _saved(placeName: '첫 일정 장소'));
    expect(TripRepository.instance.lastPlan!.stops.single.name, '첫 일정 장소');

    await _open(tester, _saved(placeName: '두 번째 일정 장소', scheduleId: 8));
    expect(TripRepository.instance.lastPlan!.stops.single.name, '두 번째 일정 장소');
  });

  testWidgets('지역을 모르는 옛 일정은 맥락으로 삼지 않는다', (tester) async {
    await _open(tester, _saved(placeName: '옛 일정 장소', province: null, city: null));

    // 동선을 다시 짤 수 없는 일정이라 고치기 입구 자체가 닫혀 있다.
    // 반쯤 채운 맥락을 남기면 탐색이 그것으로 요청을 만들어 실패한다.
    expect(TripRepository.instance.lastPlan, isNull);
  });
}
