// 저장된 일정에서 '일정 편집' 입구가 실제로 그려지는지 본다.
//
// 이 버튼은 저장 일정에서는 쓰이지 않는 쪽 머리말 안에 있었다. 저장된 일정은
// 다른 머리말을 타므로 조건을 아무리 만족해도 화면에 나온 적이 없었다. 조건을
// 고치는 것으로는 못 잡는 결함이라, 여기서는 "그려지는가"만 본다.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/maps/map_bootstrap.dart';
import 'package:map_service_client/core/state/trip_repository.dart';
import 'package:map_service_client/features/trip/screens/trip_created_screen.dart';

import 'google_map_screen_test.dart' show stop;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    mapsReady.value = false;
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

  SavedTrip trip({String? province, String? city}) => SavedTrip(
        scheduleId: 7,
        name: '서울 종로 여행',
        route: '',
        savedAt: DateTime(2026, 1, 1),
        tripStartDate: DateTime(2026, 1, 1),
        tripEndDate: DateTime(2026, 1, 1),
        stops: [stop('출발'), stop('도착', order: 2)],
        totalDurationMinutes: 24,
        province: province,
        city: city,
      );

  Future<void> mount(WidgetTester tester, SavedTrip saved) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: TripCreatedScreen(savedTrip: saved))),
    );
    await tester.pump();
  }

  testWidgets('지역을 아는 저장 일정에는 편집 입구가 보인다', (tester) async {
    await mount(tester, trip(province: '서울특별시', city: '종로구'));

    expect(find.text('일정 편집'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('지역을 모르는 옛 일정에는 편집 입구를 감춘다', (tester) async {
    await mount(tester, trip());

    expect(find.text('일정 편집'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
