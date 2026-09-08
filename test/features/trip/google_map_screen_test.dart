import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;
import 'package:map_service_client/core/api/trip_api_service.dart';
import 'package:map_service_client/core/maps/map_adapter.dart';
import 'package:map_service_client/core/maps/map_bootstrap.dart';
import 'package:map_service_client/features/trip/screens/google_map_screen.dart';

TripTransportToNext route({String source = 'OSRM', List<List<double>>? path}) =>
    TripTransportToNext(
      type: 'walk',
      label: '도보',
      durationMinutes: 12,
      distanceKm: 0.9,
      source: source,
      routeProfile: 'foot',
      path:
          path ??
          [
            [37, 127],
            [37.005, 126.9],
            [37.01, 127.01],
          ],
    );

TripStop stop(
  String name, {
  int order = 1,
  int day = 1,
  double lat = 37,
  double lng = 127,
  TripTransportToNext? transport,
}) => TripStop(
  order: order,
  day: day,
  name: name,
  address: '공개 시험 장소',
  time: '10:00',
  latitude: lat,
  longitude: lng,
  transportToNext: transport,
);

void main() {
  test(
    'verified legs remain separate across a missing route and day boundary',
    () {
      final data = TripMapDayData([
        stop('A', order: 30, transport: route()),
        stop(
          'B',
          order: 10,
          lat: 37.01,
          lng: 127.01,
          transport: route(source: 'UNKNOWN'),
        ),
        stop(
          'C',
          order: 20,
          lat: 37.02,
          lng: 127.02,
          transport: route(
            path: [
              [37.02, 127.02],
              [37.025, 127.024],
              [37.03, 127.03],
            ],
          ),
        ),
        stop('D', order: 40, lat: 37.03, lng: 127.03, transport: route()),
        stop('tomorrow', day: 2, lat: 38, lng: 128),
      ], 1);
      expect(data.stops.map((s) => s.name), ['A', 'B', 'C', 'D']);
      expect(data.unavailableLegs, 1);
      final store = MapOverlayStore();
      addTearDown(store.dispose);
      for (final leg in data.routes) {
        store.add(leg);
      }
      expect(store.polylines, hasLength(2));
      expect(store.polylines.map((p) => p.polylineId.value).toSet(), {
        'day_1_leg_0',
        'day_1_leg_2',
      });
      expect(store.polylines.first.points, [
        const google.LatLng(37, 127),
        const google.LatLng(37.005, 126.9),
        const google.LatLng(37.01, 127.01),
      ]);
      expect(data.bounds!.southWest.longitude, 126.9);
      expect(data.bounds!.northEast.latitude, 37.03);
    },
  );

  test('invalid middle-stop coordinates never connect its neighbors', () {
    final data = TripMapDayData([
      stop('A', transport: route()),
      stop('invalid', lat: double.nan, transport: route()),
      stop('C', lat: 37.01),
    ], 1);
    expect(data.markerPositions.keys, [0, 2]);
    expect(data.invalidStops, 1);
    expect(data.routes, isEmpty);
    expect(data.unavailableLegs, 2);
  });

  test('unverified or malformed geometry produces no map line', () {
    for (final transport in [
      route(source: 'UNKNOWN'),
      route(source: 'ESTIMATED'),
      route(source: 'STUB'),
      route(
        path: [
          [37, 127],
          [double.nan, 127],
        ],
      ),
      route(
        path: [
          [37, 127],
          [37, 127],
        ],
      ),
    ]) {
      final data = TripMapDayData([
        stop('A', transport: transport),
        stop('B'),
      ], 1);
      expect(data.routes, isEmpty);
      expect(data.markerPositions, hasLength(2));
    }
  });

  testWidgets('empty itinerary displays no invented stops or map', (
    tester,
  ) async {
    mapsReady.value = false;
    await tester.pumpWidget(const MaterialApp(home: GoogleMapScreen()));
    expect(find.textContaining('표시할 일정이 없어요'), findsOneWidget);
    expect(find.byType(AppMap), findsNothing);
    expect(find.textContaining('속초'), findsNothing);
  });

  testWidgets(
    'day tabs retain only the selected real stops and safe SDK failure',
    (tester) async {
      mapsReady.value = false;
      await tester.pumpWidget(
        MaterialApp(
          home: GoogleMapScreen(
            stops: [
              stop('오늘 A', transport: route()),
              stop('오늘 B', lat: 37.01),
              stop('내일 C', day: 2, lat: 38),
            ],
          ),
        ),
      );
      expect(find.text('1. 오늘 A'), findsOneWidget);
      expect(find.textContaining('OpenStreetMap contributors'), findsOneWidget);
      expect(find.textContaining('지도를 불러올 수 없습니다'), findsOneWidget);
      expect(find.byType(google.GoogleMap), findsNothing);
      await tester.tap(find.text('2일차'));
      await tester.pumpAndSettle();
      expect(find.text('1. 내일 C'), findsOneWidget);
      expect(find.text('1. 오늘 A'), findsNothing);
      expect(find.textContaining('OpenStreetMap contributors'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'replacing itinerary discards previous day and selected details',
    (tester) async {
      mapsReady.value = false;
      await tester.pumpWidget(
        MaterialApp(
          home: GoogleMapScreen(
            key: const ValueKey('itinerary'),
            stops: [stop('이전 장소')],
          ),
        ),
      );
      await tester.tap(find.text('1. 이전 장소'));
      await tester.pump();
      expect(find.text('10:00 · 이전 장소'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          home: GoogleMapScreen(
            key: const ValueKey('itinerary'),
            stops: [stop('변경 장소', day: 3)],
          ),
        ),
      );
      expect(find.text('1. 변경 장소'), findsOneWidget);
      expect(find.textContaining('이전 장소'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all missing coordinates keep the itinerary readable without a map',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GoogleMapScreen(stops: [stop('좌표 없음', lat: double.infinity)]),
        ),
      );
      expect(find.textContaining('좌표를 확인할 수 없어요'), findsOneWidget);
      expect(find.text('1. 좌표 없음'), findsOneWidget);
      expect(find.byType(AppMap), findsNothing);
    },
  );
}
