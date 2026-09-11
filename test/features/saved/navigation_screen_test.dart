import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:map_service_client/core/maps/map_adapter.dart';
import 'package:map_service_client/core/state/trip_repository.dart';
import 'package:map_service_client/features/saved/screens/navigation_screen.dart';

void main() {
  testWidgets('빈 일정은 예시 경로와 위치 요청 없이 저장 목록으로 복구한다', (tester) async {
    var requests = 0;
    var locationCalls = 0;
    var compassCalls = 0;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geolocator'),
      (_) async {
        locationCalls++;
        return 0;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('hemanthraj/flutter_compass'),
      (_) async {
        compassCalls++;
        return null;
      },
    );
    final router = GoRouter(
      initialLocation: '/navigation',
      routes: [
        GoRoute(
          path: '/navigation',
          builder: (_, _) => NavigationScreen(
            trip: SavedTrip(
              scheduleId: 123,
              name: '빈 일정',
              route: '',
              savedAt: DateTime(2026, 1, 1),
              tripStartDate: DateTime(2026, 1, 1),
              tripEndDate: DateTime(2026, 1, 1),
              stops: const [],
              totalDurationMinutes: 0,
            ),
          ),
        ),
        GoRoute(
          path: '/saved',
          builder: (_, _) => const Scaffold(body: Text('저장 목록')),
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(() {
      messenger.setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/geolocator'),
        null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('hemanthraj/flutter_compass'),
        null,
      );
    });
    await http.runWithClient(
      () async {
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        expect(find.text('표시할 일정이 없어요'), findsOneWidget);
        expect(find.textContaining('속초'), findsNothing);
        expect(find.textContaining('25분'), findsNothing);
        expect(find.byType(AppMap), findsNothing);
        expect(requests, 0);
        expect(locationCalls, 0);
        expect(compassCalls, 0);
        await tester.tap(find.text('저장 일정 보기'));
        await tester.pumpAndSettle();
        expect(find.text('저장 목록'), findsOneWidget);
      },
      () => MockClient((_) async {
        requests++;
        return http.Response('{}', 500);
      }),
    );
  });
}
