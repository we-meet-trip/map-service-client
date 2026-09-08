import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/features/trip/models/trip_forecast.dart';
import 'package:map_service_client/features/trip/widgets/trip_weather_card.dart';

void main() {
  final fixedNow = DateTime.parse('2026-09-07T00:00:00Z');
  TripForecast forecast() => TripForecast.fromJson({
    'province': '부산광역시',
    'city': '해운대구',
    'daily': [
      {
        'date': '2026-09-07',
        'temp_max': 29,
        'source': 'mid_temp',
        'expires_at': '2026-09-09T00:00:00Z',
      },
      {
        'date': '2026-09-08',
        'precipitation_prob': 0,
        'sky_condition': '맑음',
        'source': 'short_term',
        'expires_at': '2026-09-09T00:00:00Z',
      },
    ],
    'missing_reasons': {'2026-09-18': 'out_of_range'},
  });

  test('partial forecasts and actual zero stay distinct', () {
    expect(
      forecast().forDate('2026-09-07', now: fixedNow)!.precipitation,
      isNull,
    );
    expect(forecast().forDate('2026-09-08', now: fixedNow)!.precipitation, 0);
    expect(forecast().forDate('2026-09-09', now: fixedNow), isNull);
  });

  test('expired data is rejected by the dated lookup', () {
    final data = TripForecast.fromJson({
      'daily': [
        {
          'date': '2026-09-07',
          'temp_max': 30,
          'expires_at': '2026-09-07T12:00:00+09:00',
        },
      ],
    });
    expect(
      data.forDate('2026-09-07', now: DateTime.parse('2026-09-07T03:00:00Z')),
      isNull,
    );
  });

  test('date keys preserve calendar dates without UTC conversion', () {
    expect(forecastDateKey(DateTime(2026, 9, 7)), '2026-09-07');
  });

  testWidgets('schedule date selects its own partial forecast', (tester) async {
    final future = Future<TripForecast?>.value(forecast());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripWeatherCard(
            now: () => fixedNow,
            forecast: future,
            date: DateTime(2026, 9, 7),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('강수확률 미제공'), findsOneWidget);
    expect(find.textContaining('맑음'), findsNothing);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripWeatherCard(
            now: () => fixedNow,
            forecast: future,
            date: DateTime(2026, 9, 8),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('강수확률 0%'), findsOneWidget);
    expect(find.textContaining('맑음'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('range outside forecast horizon is explained', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripWeatherCard(
            now: () => fixedNow,
            forecast: Future.value(forecast()),
            date: DateTime(2026, 9, 18),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('예보 제공 기간 밖'), findsOneWidget);
    expect(find.textContaining('0%'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('failed refresh does not display old region values', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripWeatherCard(
            now: () => fixedNow,
            forecast: Future.value(forecast()),
            date: DateTime(2026, 9, 8),
          ),
        ),
      ),
    );
    await tester.pump();
    final pending = Completer<TripForecast?>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripWeatherCard(
            now: () => fixedNow,
            forecast: pending.future,
            date: DateTime(2026, 9, 8),
          ),
        ),
      ),
    );
    pending.completeError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(find.textContaining('최신 예보를 확인할 수 없어요'), findsOneWidget);
    expect(find.textContaining('맑음'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  TripForecast timedForecast(DateTime? expiry, {int pop = 80}) => TripForecast(
    province: '부산광역시',
    city: '해운대구',
    daily: [
      TripForecastDay(
        date: '2026-09-07',
        precipitation: pop,
        source: 'short_term',
        expiresAt: expiry,
      ),
    ],
  );

  testWidgets('idle card hides data at expiry without a parent rebuild', (
    tester,
  ) async {
    var clock = fixedNow;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripWeatherCard(
            forecast: Future.value(
              timedForecast(clock.add(const Duration(seconds: 5))),
            ),
            date: DateTime(2026, 9, 7),
            now: () => clock,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('강수확률 80%'), findsOneWidget);
    clock = clock.add(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 6));
    expect(find.textContaining('유효 기간이 지났어요'), findsOneWidget);
    expect(find.textContaining('80%'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'resume rechecks expiry after the background timer was cancelled',
    (tester) async {
      var clock = fixedNow;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripWeatherCard(
              forecast: Future.value(
                timedForecast(clock.add(const Duration(seconds: 5))),
              ),
              date: DateTime(2026, 9, 7),
              now: () => clock,
            ),
          ),
        ),
      );
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      clock = clock.add(const Duration(hours: 1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.textContaining('유효 기간이 지났어요'), findsOneWidget);
      expect(find.textContaining('80%'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'replacing future and disposing cancel obsolete expiry callbacks',
    (tester) async {
      var clock = fixedNow;
      var reads = 0;
      DateTime now() {
        reads++;
        return clock;
      }

      Widget card(DateTime expiry, int pop) => MaterialApp(
        home: Scaffold(
          body: TripWeatherCard(
            forecast: Future.value(timedForecast(expiry, pop: pop)),
            date: DateTime(2026, 9, 7),
            now: now,
          ),
        ),
      );
      await tester.pumpWidget(card(clock.add(const Duration(seconds: 2)), 80));
      await tester.pump();
      await tester.pumpWidget(card(clock.add(const Duration(seconds: 20)), 20));
      await tester.pump();
      final afterReplacement = reads;
      clock = clock.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      expect(reads, afterReplacement);
      expect(find.textContaining('강수확률 20%'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      final afterDisposal = reads;
      clock = clock.add(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      expect(reads, afterDisposal);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unknown freshness is distinguished from an expired forecast', (
    tester,
  ) async {
    final unknown = timedForecast(null);
    expect(unknown.forDate('2026-09-07', now: fixedNow), isNull);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripWeatherCard(
            forecast: Future.value(unknown),
            date: DateTime(2026, 9, 7),
            now: () => fixedNow,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('유효 기간을 확인할 수 없어요'), findsOneWidget);
    expect(find.textContaining('유효 기간이 지났어요'), findsNothing);
    expect(find.textContaining('80%'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
