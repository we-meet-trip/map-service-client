import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/common/widgets/app_loading_screen.dart';
import 'package:map_service_client/common/widgets/external_ai_consent.dart';
import 'package:map_service_client/common/widgets/next_button.dart';
import 'package:map_service_client/core/api/api_client.dart';
import 'package:map_service_client/core/api/trip_api_service.dart';
import 'package:map_service_client/core/state/auth_store.dart';
import 'package:map_service_client/core/state/trip_repository.dart';
import 'package:map_service_client/features/place_explore/screens/place_explore_result_screen.dart';
import 'package:map_service_client/features/trip/screens/manual_plan_screen.dart';
import 'package:map_service_client/features/trip/screens/trip_regenerate_screen.dart';
import 'package:map_service_client/features/trip/screens/trip_research_result_screen.dart';
import 'package:map_service_client/features/trip/screens/trip_start_screen.dart';
import 'package:map_service_client/features/trip/screens/trip_step1_screen.dart';
import 'package:map_service_client/features/trip/screens/trip_step2_screen.dart';
import 'package:map_service_client/features/trip/screens/trip_step3_screen.dart';
import 'package:map_service_client/features/trip/screens/trip_step4_screen.dart';
import 'package:map_service_client/features/trip/screens/trip_step5_screen.dart';
import 'package:map_service_client/features/trip/utils/plan_edit_draft.dart';

class _Api implements ApiClient {
  final paths = <String>[];
  final bodies = <Object?>[];
  final pending = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    Duration? timeout,
  }) {
    paths.add(path);
    bodies.add(body);
    return pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _date = DateTime(2026, 9, 7);
TripStop _stop(String name) => TripStop(
  order: 1,
  day: 1,
  name: name,
  address: '공개 시험 장소',
  time: '',
  latitude: 37.5,
  longitude: 127,
  contentId: 'test-$name',
);
TripPlanContext _plan() => TripPlanContext(
  startDate: _date,
  endDate: _date,
  activeStartHour: 9,
  activeEndHour: 18,
  transport: 'walk',
  province: '서울특별시',
  city: '종로구',
  stops: [_stop('A'), _stop('B'), _stop('C')],
  tripId: '00000000-0000-4000-8000-000000000001',
  minBudget: 0,
  maxBudget: 50000,
  themes: ['nature'],
);
Map<String, dynamic> _response() => {
  'trip_id': '00000000-0000-4000-8000-000000000002',
  'total_duration_minutes': 30,
  'stops': <dynamic>[],
  'weather_forecast': <dynamic>[],
};
TripGenerateRequest _generate() => TripGenerateRequest(
  startDate: _date,
  endDate: _date,
  activeStartHour: 9,
  activeEndHour: 18,
  minBudget: 0,
  maxBudget: 50000,
  themes: ['nature'],
  transport: 'walk',
  province: '서울특별시',
  city: '종로구',
);
TripRouteRequest _route() => TripRouteRequest(
  startDate: _date,
  endDate: _date,
  activeStartHour: 9,
  activeEndHour: 18,
  transport: 'walk',
  province: '서울특별시',
  city: '종로구',
  places: const [],
);
TripResearchRequest _research() => TripResearchRequest(
  startDate: _date,
  endDate: _date,
  activeStartHour: 9,
  activeEndHour: 18,
  minBudget: 0,
  maxBudget: 50000,
  themes: ['nature'],
  transport: 'walk',
  province: '서울특별시',
  city: '종로구',
  prevTripId: '00000000-0000-4000-8000-000000000001',
);
Matcher _error(String code) =>
    throwsA(isA<TripApiException>().having((e) => e.error, 'code', code));

Future<void> _decision(WidgetTester tester, bool accept) async {
  await tester.pumpAndSettle();
  expect(find.text('여행 추천 외부 AI 전송 동의'), findsOneWidget);
  await tester.tap(find.text(accept ? '전송에 동의' : '동의하지 않음'));
  await tester.pump();
}

ManualPlanScreen _editor(
  PlanEditDraft draft,
  Future<TripGenerateResponse> Function(TripRouteRequest) route,
  void Function(TripGenerateResponse) onRouted,
) => ManualPlanScreen(
  initialStops: draft.stops,
  draft: draft,
  route: route,
  consentGate: ExternalAiConsentGate(),
  startDate: _date,
  endDate: _date,
  activeStartHour: 9,
  activeEndHour: 18,
  transport: 'walk',
  province: '서울특별시',
  city: '종로구',
  onRouted: onRouted,
  onCancel: () {},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
    await AuthStore.instance.save(
      const AuthTokens(
        accessToken: 'test-a',
        refreshToken: 'test-ra',
        userId: 1,
      ),
    );
    TripRepository.instance.lastPlan = null;
    TripRepository.instance.pendingTrip = null;
  });

  test('all AI APIs deny omitted or revoked consent before any HTTP', () async {
    final http = _Api();
    final api = TripApiService(api: http);
    await expectLater(
      api.generateTrip(_generate()),
      _error('AI_CONSENT_REQUIRED'),
    );
    await expectLater(api.routeTrip(_route()), _error('AI_CONSENT_REQUIRED'));
    await expectLater(
      api.researchTrip(_research()),
      _error('AI_CONSENT_REQUIRED'),
    );
    await expectLater(
      api.routeTrip(_route(), canSend: () => false),
      _error('AI_CONSENT_REQUIRED'),
    );
    expect(http.paths, isEmpty);
  });

  for (final type in ['generate', 'route', 'research']) {
    test(
      '$type API refuses an old-account response even if caller consent callback stays true',
      () async {
        final http = _Api();
        final api = TripApiService(api: http);
        final response = switch (type) {
          'generate' => api.generateTrip(_generate(), canSend: () => true),
          'route' => api.routeTrip(_route(), canSend: () => true),
          _ => api.researchTrip(_research(), canSend: () => true),
        };
        final rejected = expectLater(response, _error('SESSION_CHANGED'));
        expect(http.paths, ['/api/v1/trip/$type']);
        await AuthStore.instance.save(
          const AuthTokens(
            accessToken: 'test-b',
            refreshToken: 'test-rb',
            userId: 2,
          ),
        );
        http.pending.complete(_response());
        await rejected;
      },
    );
  }

  test('permission withdrawn while request pending rejects response', () async {
    final http = _Api();
    var allowed = true;
    final result = TripApiService(
      api: http,
    ).routeTrip(_route(), canSend: () => allowed);
    final rejected = expectLater(result, _error('SESSION_CHANGED'));
    allowed = false;
    http.pending.complete(_response());
    await rejected;
  });

  testWidgets('manual refusal keeps edited order/transport and sends nothing', (
    tester,
  ) async {
    final draft = PlanEditDraft(
      stops: [_stop('A'), _stop('B')],
      transport: 'walk',
    );
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _editor(draft, (_) async {
            calls++;
            throw StateError('must not send');
          }, (_) {}),
        ),
      ),
    );
    await tester.tap(find.widgetWithText(ChoiceChip, '자전거'));
    tester
        .widget<ReorderableListView>(find.byType(ReorderableListView))
        .onReorder(0, 2);
    await tester.pump();
    await tester.tap(find.text('동선 만들기  →'));
    await _decision(tester, false);
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(draft.transport, 'bicycle');
    expect(draft.stops.map((s) => s.name), ['B', 'A']);
    expect(find.byType(AppLoadingScreen), findsNothing);
  });

  testWidgets(
    'duplicate taps send once; account switch prevents route result from being saved',
    (tester) async {
      final draft = PlanEditDraft(
        stops: [_stop('A'), _stop('B')],
        transport: 'walk',
      );
      final pending = Completer<TripGenerateResponse>();
      var calls = 0;
      var routed = 0;
      final original = _plan();
      TripRepository.instance.setLastPlan(original);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _editor(draft, (_) {
              calls++;
              return pending.future;
            }, (_) => routed++),
          ),
        ),
      );
      final next = tester
          .widget<NextButton>(find.byType(NextButton))
          .onPressed!;
      next();
      next();
      await _decision(tester, true);
      next();
      await tester.pump();
      expect(calls, 1);
      await tester.runAsync(
        () => AuthStore.instance.save(
          const AuthTokens(
            accessToken: 'test-b',
            refreshToken: 'test-rb',
            userId: 2,
          ),
        ),
      );
      pending.complete(
        TripGenerateResponse(
          tripId: 'new',
          totalDurationMinutes: 30,
          stops: [_stop('C')],
          weatherForecast: const [],
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(routed, 0);
      expect(TripRepository.instance.lastPlan, same(original));
      expect(draft.stops.map((s) => s.name), ['A', 'B']);
      expect(find.byType(AppLoadingScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'automatic research waits for first-frame consent; cancel preserves plan',
    (tester) async {
      final plan = _plan();
      TripRepository.instance.setLastPlan(plan);
      final http = _Api();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripResearchResultScreen(
              api: TripApiService(api: http),
              consentGate: ExternalAiConsentGate(),
            ),
          ),
        ),
      );
      await _decision(tester, false);
      await tester.pumpAndSettle();
      expect(http.paths, isEmpty);
      expect(TripRepository.instance.lastPlan, same(plan));
      expect(find.byType(AppLoadingScreen), findsNothing);
      expect(find.text('동의 확인하고 재탐색'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final all in [true, false]) {
    testWidgets(
      'explore ${all ? 'route' : 'research'} decline preserves selection; retry sends exact API once',
      (tester) async {
        final plan = _plan();
        TripRepository.instance.setLastPlan(plan);
        final selected = all ? {'stop_0', 'stop_1', 'stop_2'} : {'stop_0'};
        final before = Set<String>.of(selected);
        final http = _Api();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PlaceExploreResultScreen(
                selectedIds: selected,
                api: TripApiService(api: http),
                consentGate: ExternalAiConsentGate(),
              ),
            ),
          ),
        );
        await _decision(tester, false);
        await tester.pumpAndSettle();
        expect(http.paths, isEmpty);
        expect(selected, before);
        expect(TripRepository.instance.lastPlan, same(plan));
        expect(find.byType(AppLoadingScreen), findsNothing);
        await tester.tap(find.text('동의 확인하고 일정 만들기'));
        await _decision(tester, true);
        await tester.pump();
        expect(http.paths, [
          all ? '/api/v1/trip/route' : '/api/v1/trip/research',
        ]);
        await tester.pumpWidget(const SizedBox());
        http.pending.complete(_response());
        await tester.pump(const Duration(seconds: 3));
        expect(TripRepository.instance.lastPlan, same(plan));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'wizard generates only after consent and preserves all form inputs on refusal',
    (tester) async {
      final http = _Api();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripRegenerateScreen(
              api: TripApiService(api: http),
              consentGate: ExternalAiConsentGate(),
            ),
          ),
        ),
      );
      tester.widget<TripStartScreen>(find.byType(TripStartScreen)).onStart();
      await tester.pump();
      final step1 = tester.widget<TripStep1Screen>(
        find.byType(TripStep1Screen),
      );
      step1.onDateChanged(_date, _date);
      step1.onTimeChanged(9, 18);
      step1.onNext();
      await tester.pump();
      final step2 = tester.widget<TripStep2Screen>(
        find.byType(TripStep2Screen),
      );
      step2.onBudgetChanged(10000, 50000);
      step2.onNext();
      await tester.pump();
      final step3 = tester.widget<TripStep3Screen>(
        find.byType(TripStep3Screen),
      );
      step3.onThemesChanged({'nature'});
      step3.onNext();
      await tester.pump();
      final step4 = tester.widget<TripStep4Screen>(
        find.byType(TripStep4Screen),
      );
      step4.onTransportChanged('walk');
      step4.onNext();
      await tester.pump();
      final step5 = tester.widget<TripStep5Screen>(
        find.byType(TripStep5Screen),
      );
      step5.onLocationChanged('서울특별시', '종로구');
      step5.onNext();
      step5.onNext();
      await _decision(tester, false);
      await tester.pumpAndSettle();
      expect(http.paths, isEmpty);
      expect(find.byType(AppLoadingScreen), findsNothing);
      final retained = tester.widget<TripStep5Screen>(
        find.byType(TripStep5Screen),
      );
      expect(retained.selectedProvince, '서울특별시');
      expect(retained.selectedCity, '종로구');
      retained.onNext();
      await _decision(tester, true);
      await tester.pump();
      expect(http.paths, ['/api/v1/trip/generate']);
      final body = http.bodies.single as Map<String, dynamic>;
      expect(body['budget'], {'min': 10000, 'max': 50000});
      expect(body['themes'], ['nature']);
      expect(body['transport'], 'walk');
      expect(body['schedule'], containsPair('active_start_hour', 9));
      await tester.pumpWidget(const SizedBox());
      http.pending.complete(_response());
      await tester.pump(const Duration(seconds: 3));
      expect(TripRepository.instance.lastPlan, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
