import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/api/transit_route_options_service.dart';

/// 통합 길찾기 경로 후보 응답 해석 검증.
///
/// 서버는 geometry 와 stops 를 같은 원본에서 뽑되 결측 처리를 다르게 한다.
/// geometry 는 좌표가 없으면 시작/끝으로 대체되지만 stops 는 대체하지 않고
/// 비워 보낸다. 화면이 "N개 정류장"을 그 목록으로 그리므로, 앱도 비어 있는
/// 상태를 그대로 열어야 실제 경유 수를 지어내지 않는다.
void main() {
  Map<String, dynamic> legJson({
    Object? type = 'subway',
    Object? lineName = '2호선',
    Object? stationCount = 3,
    Object? geometry,
    Object? stops,
  }) =>
      {
        'type': type,
        'line_name': lineName,
        'start_name': '시청',
        'end_name': '여의도',
        'section_time_min': 12,
        'station_count': stationCount,
        'geometry': geometry ??
            [
              [37.5665, 126.9780],
              [37.5228, 126.9227],
            ],
        'stops': stops ?? ['시청', '충정로', '여의도'],
      };

  Map<String, dynamic> optionJson({
    Object? modes,
    List<Map<String, dynamic>>? legs,
  }) =>
      {
        'total_time_min': 33,
        'fare': 1400,
        'transfer_count': 1,
        'total_walk_m': 520,
        'modes': modes ?? ['subway'],
        'legs': legs ?? [legJson()],
      };

  group('TransitRouteLeg.fromJson', () {
    test('이동수단과 구간 정보를 그대로 싣는다', () {
      final leg = TransitRouteLeg.fromJson(legJson());

      expect(leg.type, TransitLegType.subway);
      expect(leg.lineName, '2호선');
      expect(leg.startName, '시청');
      expect(leg.endName, '여의도');
      expect(leg.sectionTimeMinutes, 12);
      expect(leg.stationCount, 3);
      expect(leg.geometry, hasLength(2));
      expect(leg.geometry.first, [37.5665, 126.9780]);
      expect(leg.stopNames, ['시청', '충정로', '여의도']);
    });

    test('버스 구간도 그대로 열린다', () {
      final leg = TransitRouteLeg.fromJson(
        legJson(type: 'bus', lineName: '402번'),
      );

      expect(leg.type, TransitLegType.bus);
      expect(leg.lineName, '402번');
    });

    test('모르는 이동수단은 도보로 본다', () {
      expect(
        TransitRouteLeg.fromJson(legJson(type: 'tram')).type,
        TransitLegType.walk,
      );
      expect(
        TransitRouteLeg.fromJson(legJson(type: null)).type,
        TransitLegType.walk,
      );
    });

    test('노선명과 역 수가 없으면 null 로 둔다', () {
      final leg = TransitRouteLeg.fromJson(
        legJson(type: 'walk', lineName: null, stationCount: null),
      );

      expect(leg.lineName, isNull);
      // 0 으로 바꾸면 "정류장 0개"라는 뜻이 되어 화면이 잘못 표시한다.
      expect(leg.stationCount, isNull);
    });

    test('도보 구간처럼 좌표·정류장이 비어도 그대로 열린다', () {
      final leg = TransitRouteLeg.fromJson(
        legJson(type: 'walk', geometry: <dynamic>[], stops: <dynamic>[]),
      );

      expect(leg.geometry, isEmpty);
      expect(leg.stopNames, isEmpty);
    });

    test('stops 가 비어 있어도 시작·끝 이름으로 채우지 않는다', () {
      // 서버가 일부러 비워 보내는 경우다(버스는 가끔 목록이 비어 온다).
      // 앱이 여기서 두 개를 지어내면 "2개 정류장"으로 잘못 표시된다.
      final leg = TransitRouteLeg.fromJson(legJson(stops: <dynamic>[]));

      expect(leg.stopNames, isEmpty);
      // geometry 는 같은 응답에서 채워져 온다 — 둘의 처리가 다르다.
      expect(leg.geometry, isNotEmpty);
    });

    test('키 자체가 없거나 형태가 어긋나도 빈 목록으로 연다', () {
      final missing = TransitRouteLeg.fromJson({
        'type': 'bus',
        'start_name': '정류장',
        'end_name': '도착 정류장',
        'section_time_min': 7,
      });

      expect(missing.geometry, isEmpty);
      expect(missing.stopNames, isEmpty);
    });

    test('좌표가 두 값에 못 미치는 항목은 버린다', () {
      final leg = TransitRouteLeg.fromJson(legJson(geometry: [
        [37.5665],
        [37.5228, 126.9227],
      ]));

      expect(leg.geometry, hasLength(1));
      expect(leg.geometry.single, [37.5228, 126.9227]);
    });
  });

  group('TransitRouteOption.fromJson', () {
    test('후보 요약과 구간 목록을 함께 싣는다', () {
      final option = TransitRouteOption.fromJson(optionJson());

      expect(option.totalTimeMinutes, 33);
      expect(option.fare, 1400);
      expect(option.transferCount, 1);
      expect(option.totalWalkMeters, 520);
      expect(option.modes, [TransitLegType.subway]);
      expect(option.legs, hasLength(1));
    });

    test('혼합 경로의 이동수단을 순서대로 싣는다', () {
      final option = TransitRouteOption.fromJson(
        optionJson(
          modes: ['subway', 'bus'],
          legs: [legJson(), legJson(type: 'bus', lineName: '402번')],
        ),
      );

      expect(option.modes, [TransitLegType.subway, TransitLegType.bus]);
      expect(
        option.legs.map((l) => l.type),
        [TransitLegType.subway, TransitLegType.bus],
      );
    });

    test('숫자 필드가 없으면 0 으로 연다', () {
      final option = TransitRouteOption.fromJson({
        'modes': ['bus'],
        'legs': <dynamic>[],
      });

      expect(option.totalTimeMinutes, 0);
      expect(option.fare, 0);
      expect(option.transferCount, 0);
      expect(option.totalWalkMeters, 0);
      expect(option.legs, isEmpty);
    });

    test('modes 나 legs 가 목록이 아니면 빈 목록으로 연다', () {
      final option = TransitRouteOption.fromJson({
        'total_time_min': 10,
        'modes': 'subway',
        'legs': null,
      });

      expect(option.modes, isEmpty);
      expect(option.legs, isEmpty);
    });
  });

  group('TransitSearchMode', () {
    test('서버에 보내는 값이 계약과 맞는다', () {
      expect(TransitSearchMode.all.wireValue, 'all');
      expect(TransitSearchMode.subway.wireValue, 'subway');
      expect(TransitSearchMode.bus.wireValue, 'bus');
    });
  });

  group('거리와 버스 비중', () {
    test('구간 거리와 후보의 거리·비중을 그대로 싣는다', () {
      final option = TransitRouteOption.fromJson({
        ...optionJson(),
        'subway_distance_m': 2000,
        'bus_distance_m': 8000,
        'bus_distance_ratio': 0.8,
        'legs': [
          {...legJson(), 'distance_m': 2000},
        ],
      });

      expect(option.subwayDistanceMeters, 2000);
      expect(option.busDistanceMeters, 8000);
      expect(option.busDistanceRatio, 0.8);
      expect(option.legs.single.distanceMeters, 2000);
    });

    test('거리 필드가 없는 과거 형식 응답도 그대로 열린다', () {
      // 서버가 아직 안 올라간 상태에서도 화면이 죽지 않아야 한다.
      final option = TransitRouteOption.fromJson(optionJson());

      expect(option.subwayDistanceMeters, 0);
      expect(option.busDistanceMeters, 0);
      expect(option.busDistanceRatio, 0.0);
      expect(option.legs.single.distanceMeters, 0);
    });

    test('정수로 와도 비중을 double 로 읽는다', () {
      final option = TransitRouteOption.fromJson({
        ...optionJson(),
        'bus_distance_ratio': 1,
      });

      expect(option.busDistanceRatio, 1.0);
    });
  });

  group('시외버스', () {
    test('시외버스 구간을 도보가 아니라 제 항목으로 연다', () {
      // 이 매핑이 없으면 도시 간 이동이 "도보 217분"으로 표시된다.
      final leg = TransitRouteLeg.fromJson(
        legJson(type: 'intercity', lineName: '시외버스', stationCount: null),
      );

      expect(leg.type, TransitLegType.intercity);
      expect(leg.lineName, '시외버스');
    });

    test('modes 에 시외버스가 실린다', () {
      final option = TransitRouteOption.fromJson(
        optionJson(
          modes: ['intercity'],
          legs: [legJson(type: 'intercity')],
        ),
      );

      expect(option.modes, [TransitLegType.intercity]);
      expect(option.legs.single.type, TransitLegType.intercity);
    });

    test('지하철·시내버스와 섞여도 순서대로 연다', () {
      final option = TransitRouteOption.fromJson(
        optionJson(modes: ['subway', 'bus', 'intercity']),
      );

      expect(option.modes, [
        TransitLegType.subway,
        TransitLegType.bus,
        TransitLegType.intercity,
      ]);
    });
  });
}
