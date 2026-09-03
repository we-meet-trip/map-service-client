import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/api/subway_route_service.dart';

void main() {
  test('경로가 있으면 구간까지 읽는다', () {
    final r = parseSubwayRouteResponse({
      'status': 'ok',
      'route': {
        'total_time_min': 42,
        'fare': 1450,
        'transfer_count': 1,
        'total_walk_m': 380,
        'steps': [
          {'type': 'walk', 'start_name': '출발', 'end_name': '강남', 'section_time_min': 5},
          {
            'type': 'subway',
            'line_name': '2호선',
            'start_name': '강남',
            'end_name': '사당',
            'section_time_min': 30,
            'station_count': 7,
          },
        ],
      },
    });

    expect(r.status, SubwayRouteStatus.ok);
    expect(r.route!.totalTimeMinutes, 42);
    expect(r.route!.fare, 1450);
    expect(r.route!.steps.length, 2);
    expect(r.route!.steps[1].type, SubwayStepType.subway);
    expect(r.route!.steps[1].lineName, '2호선');
    expect(r.route!.steps[1].stationCount, 7);
    expect(r.route!.steps[0].type, SubwayStepType.walk);
    expect(r.route!.steps[0].stationCount, isNull);
  });

  test('길이 없는 것과 물어보지 못한 것이 갈린다', () {
    final notFound = parseSubwayRouteResponse({'status': 'not_found'});
    final unavailable = parseSubwayRouteResponse({'status': 'unavailable'});

    expect(notFound.status, SubwayRouteStatus.notFound);
    expect(unavailable.status, SubwayRouteStatus.unavailable);
    expect(notFound.route, isNull);
    expect(unavailable.route, isNull);
    // 두 값이 같아지면 바깥 장애가 "길 없음"으로 보인다.
    expect(notFound.status, isNot(unavailable.status));
  });
}
