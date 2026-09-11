import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/maps/map_bootstrap.dart';
import 'package:map_service_client/core/state/trip_repository.dart';
import 'package:map_service_client/features/saved/screens/navigation_screen.dart';
import 'package:map_service_client/features/trip/screens/trip_created_screen.dart';

import 'google_map_screen_test.dart' show route, stop;

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

  for (final transport in [
    route(source: 'UNKNOWN'),
    route(),
    route(type: 'scooter', profile: 'bicycle'),
  ]) {
    for (final navigation in [false, true]) {
      testWidgets(
        '${navigation ? '길안내' : '생성 일정'} 신뢰도 안내 ${transport.source}/${transport.type}',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(320, 1200));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final trip = SavedTrip(
            name: '경로 안내 시험',
            route: '',
            savedAt: DateTime(2026, 1, 1),
            tripStartDate: DateTime(2026, 1, 1),
            tripEndDate: DateTime(2026, 1, 1),
            stops: [
              stop('출발', transport: transport),
              stop('경유', order: 2, transport: transport),
              stop('도착', order: 3),
            ],
            totalDurationMinutes: 24,
          );
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!,
              ),
              home: navigation
                  ? NavigationScreen(trip: trip)
                  : Scaffold(body: TripCreatedScreen(savedTrip: trip)),
            ),
          );
          await tester.pump();
          final descriptions = find.text(transport.routeDescription);
          await tester.ensureVisible(descriptions.last);
          await tester.pump();
          expect(descriptions, findsNWidgets(2));
          expect(find.textContaining('속초'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
