import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/api/trip_api_service.dart';

void main() {
  Map<String, dynamic> route({String? source, String? profile}) => {
    'type': 'walk', 'label': '이동: 도보',
    'duration_minutes': 12, 'distance_km': 0.9,
    'path': [[37.5, 127.0], [37.501, 127.001], [37.51, 127.01]],
    'source': ?source,
    'route_profile': ?profile,
  };

  test('old or estimated geometry is not displayed as a verified road route', () {
    for (final json in [route(), route(source: 'ESTIMATED'), route(source: 'STUB')]) {
      final value = TripTransportToNext.fromJson(json);
      expect(value.hasRoadRoute, isFalse);
      expect(value.routeDescription, contains('경로 미확인'));
      expect(value.routeDescription, contains('추정'));
    }
  });

  test('provider provenance and profile survive response parsing', () {
    final value = TripTransportToNext.fromJson(route(source: 'OSRM', profile: 'foot'));
    expect(value.hasRoadRoute, isTrue);
    expect(value.routeDescription, contains('예상 소요 시간'));
    final scooter = TripTransportToNext.fromJson({
      ...route(source: 'OSRM', profile: 'bicycle'), 'type': 'scooter',
    });
    expect(scooter.routeDescription, contains('자전거 경로 기준'));
    expect(scooter.routeDescription, contains('킥보드 시간 추정'));
  });

  test('malformed or nonfinite geometry is not used for map overlays', () {
    for (final path in [
      [[37.5, 127.0]],
      [[37.5, 127.0], [double.nan, 127.0]],
      [[127.0, 37.5], [127.1, 37.6]],
      [[37.5], [37.6]],
      [[37.5, 127.0], [37.5, 127.0]],
    ]) {
      final value = TripTransportToNext.fromJson({
        ...route(source: 'OSRM', profile: 'foot'), 'path': path,
      });
      expect(value.hasRoadRoute, isFalse);
    }
    expect(TripTransportToNext.fromJson(route(source: 'OSRM', profile: 'bicycle')).hasRoadRoute, isFalse);
  });
}
