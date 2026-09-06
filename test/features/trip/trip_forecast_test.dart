import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/features/trip/models/trip_forecast.dart';
import 'package:map_service_client/features/trip/widgets/trip_weather_card.dart';

void main() {
  TripForecast forecast() => TripForecast.fromJson({
    'province': '부산광역시',
    'city': '해운대구',
    'daily': [
      {'date': '2026-09-07', 'temp_max': 29, 'source': 'mid_temp'},
      {
        'date': '2026-09-08',
        'precipitation_prob': 0,
        'sky_condition': '맑음',
        'source': 'short_term',
      },
    ],
    'missing_reasons': {'2026-09-18': 'out_of_range'},
  });

  test('partial forecasts and actual zero stay distinct', () {
    expect(forecast().forDate('2026-09-07')!.precipitation, isNull);
    expect(forecast().forDate('2026-09-08')!.precipitation, 0);
    expect(forecast().forDate('2026-09-09'), isNull);
  });

  test('expired data is rejected even while screen remains open', () {
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
          body: TripWeatherCard(forecast: future, date: DateTime(2026, 9, 7)),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('강수확률 미제공'), findsOneWidget);
    expect(find.textContaining('맑음'), findsNothing);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripWeatherCard(forecast: future, date: DateTime(2026, 9, 8)),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('강수확률 0%'), findsOneWidget);
    expect(find.textContaining('맑음'), findsOneWidget);
  });

  testWidgets('range outside forecast horizon is explained', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripWeatherCard(
            forecast: Future.value(forecast()),
            date: DateTime(2026, 9, 18),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('예보 제공 기간 밖'), findsOneWidget);
    expect(find.textContaining('0%'), findsNothing);
  });

  testWidgets('failed refresh does not display old region values', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripWeatherCard(
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
  });
}
