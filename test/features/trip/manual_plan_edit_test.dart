import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/api/api_client.dart';
import 'package:map_service_client/core/api/trip_api_service.dart';
import 'package:map_service_client/core/state/trip_repository.dart';
import 'package:map_service_client/features/trip/screens/manual_plan_screen.dart';
import 'package:map_service_client/features/trip/screens/saved_plan_edit_screen.dart';
import 'package:map_service_client/features/trip/utils/plan_edit_draft.dart';

TripStop stop(String name, {int day = 1}) => TripStop(
  order: 1,
  day: day,
  name: name,
  address: '$name address',
  time: '',
  latitude: 37.5,
  longitude: 127.0,
  contentId: 'place-$name',
);

void main() {
  test(
    'draft reorder and day move retain other stop order; cancel restores source',
    () {
      final source = [
        stop('A'),
        stop('B'),
        stop('C', day: 2),
        stop('D', day: 2),
      ];
      final draft = PlanEditDraft(stops: source, transport: 'walk');
      draft.reorderWithinDay(1, 0, 2);
      expect(draft.stops.map((s) => s.name), ['B', 'A', 'C', 'D']);
      draft.moveToDay(draft.stops.first, 2);
      expect(draft.stops.map((s) => s.name), ['A', 'C', 'D', 'B']);
      expect(draft.stops.last.day, 2);
      expect(draft.stops.last.contentId, 'place-B');
      draft.transport = 'bicycle';
      draft.stops.add(stop('E', day: 2));
      expect(draft.isDirty, isTrue);
      expect(source.map((s) => s.name), ['A', 'B', 'C', 'D']);
      draft.reset();
      expect(draft.isDirty, isFalse);
      expect(draft.stops, source);
      expect(draft.transport, 'walk');
    },
  );

  testWidgets('transport and dragged order are used for route recalculation', (
    tester,
  ) async {
    final draft = PlanEditDraft(
      stops: [stop('A'), stop('B')],
      transport: 'walk',
    );
    TripRouteRequest? captured;
    var routed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _editor(
            draft,
            route: (request) async {
              captured = request;
              return TripGenerateResponse(
                tripId: 'new-job',
                totalDurationMinutes: 80,
                stops: draft.stops,
                weatherForecast: const [],
              );
            },
            onRouted: (_) => routed++,
          ),
        ),
      ),
    );
    await tester.tap(find.widgetWithText(ChoiceChip, '자전거'));
    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    list.onReorder(0, 2);
    await tester.pump();
    await tester.tap(find.text('동선 만들기  →'));
    await tester.pump();
    await _acceptAiConsent(tester);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(captured!.transport, 'bicycle');
    expect(captured!.places.map((p) => p.name), ['B', 'A']);
    expect(captured!.toJson()['optimize'], isFalse);
    expect(routed, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'cancel confirmation can keep editing or discard the isolated draft',
    (tester) async {
      final source = [stop('A'), stop('B')];
      final draft = PlanEditDraft(stops: source, transport: 'walk');
      var cancelled = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: _editor(draft, onCancel: () => cancelled++)),
        ),
      );
      await tester.tap(find.widgetWithText(ChoiceChip, '자전거'));
      await tester.tap(find.text('수정 취소'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('계속 수정'));
      await tester.pumpAndSettle();
      expect(cancelled, 0);
      expect(draft.transport, 'bicycle');
      await tester.tap(find.text('수정 취소'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('수정 취소'),
        ),
      );
      await tester.pumpAndSettle();
      expect(cancelled, 1);
      expect(draft.transport, 'walk');
      expect(draft.stops, source);
    },
  );

  testWidgets(
    'save failure retains transport and reordered stops for retry without changing saved trip',
    (tester) async {
      final source = [stop('A'), stop('B')];
      final trip = SavedTrip(
        scheduleId: 7,
        name: 'saved',
        route: '',
        savedAt: DateTime.utc(2026),
        tripStartDate: DateTime.utc(2026, 9, 6),
        tripEndDate: DateTime.utc(2026, 9, 6),
        stops: source,
        totalDurationMinutes: 50,
        province: '서울특별시',
        city: '종로구',
        transport: 'walk',
      );
      TripRepository.instance.plannedTrips.value = [trip];
      addTearDown(() => TripRepository.instance.plannedTrips.value = []);
      final routed = <TripRouteRequest>[];
      final savedTransports = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SavedPlanEditScreen(
              trip: trip,
              route: (request) async {
                routed.add(request);
                return TripGenerateResponse(
                  tripId: 'retry-job',
                  totalDurationMinutes: 80,
                  stops: source,
                  weatherForecast: const [],
                );
              },
              revise: (id, jobId, transport) async {
                expect(id, 7);
                expect(jobId, 'retry-job');
                savedTransports.add(transport);
                throw const ApiException(
                  statusCode: 503,
                  code: 'UNAVAILABLE',
                  message: 'retry',
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.widgetWithText(ChoiceChip, '자전거'));
      tester
          .widget<ReorderableListView>(find.byType(ReorderableListView))
          .onReorder(0, 2);
      await tester.pump();
      for (var attempt = 0; attempt < 2; attempt++) {
        await tester.tap(find.text('동선 만들기  →'));
        await tester.pump();
        await _acceptAiConsent(tester);
        await tester.pump(const Duration(seconds: 3));
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '자전거'))
              .selected,
          isTrue,
        );
      }
      expect(savedTransports, ['bicycle', 'bicycle']);
      expect(routed.map((r) => r.places.map((p) => p.name).toList()), [
        ['B', 'A'],
        ['B', 'A'],
      ]);
      expect(TripRepository.instance.plannedTrips.value.single, same(trip));
      expect(trip.transport, 'walk');
      expect(trip.stops.map((s) => s.name), ['A', 'B']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('missing edit target shows a safe return screen', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SavedPlanEditScreen(trip: null))),
    );
    expect(find.textContaining('고칠 일정을 찾지 못했어요'), findsOneWidget);
    expect(find.byType(ManualPlanScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _acceptAiConsent(WidgetTester tester) async {
  if (find.text('전송에 동의').evaluate().isEmpty) return;
  await tester.pumpAndSettle();
  await tester.tap(find.text('전송에 동의'));
  await tester.pump();
}

ManualPlanScreen _editor(
  PlanEditDraft draft, {
  Future<TripGenerateResponse> Function(TripRouteRequest)? route,
  void Function(TripGenerateResponse)? onRouted,
  VoidCallback? onCancel,
}) => ManualPlanScreen(
  draft: draft,
  initialStops: draft.stops,
  startDate: DateTime.utc(2026, 9, 6),
  endDate: DateTime.utc(2026, 9, 6),
  activeStartHour: 9,
  activeEndHour: 20,
  transport: 'walk',
  province: '서울특별시',
  city: '종로구',
  route: route,
  onRouted: onRouted ?? (_) {},
  onCancel: onCancel ?? () {},
);
