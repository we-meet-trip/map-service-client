// 경로 지도의 실제 노선 좌표 조회가 "실패하면 직선 유지"를 지키는지 본다.
//
// 이 조회는 부가 정보다. 서버가 못 주거나 모양이 어긋나면 화면은 이미 가진
// 정류장 직선을 그대로 그리면 된다 — 예외가 새어 나가 지도 화면이 오류로
// 바뀌거나, 어긋난 좌표가 엉뚱한 구간에 입혀지면 안 된다.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:map_service_client/core/api/transit_route_options_service.dart';

http.Response _json(Object body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

TransitRouteLeg _leg(TransitLegType type, List<List<double>> geometry) =>
    TransitRouteLeg(
      type: type,
      lineName: type == TransitLegType.walk ? null : '2호선',
      startName: '시청',
      endName: '여의도',
      sectionTimeMinutes: 12,
      geometry: geometry,
      stopNames: const ['시청', '충정로', '여의도'],
    );

const _straight = [
  [37.5665, 126.9780],
  [37.5228, 126.9227],
];

TransitRouteOption _option({String? mapObj = '18:2:132:136@204:2:917:915'}) =>
    TransitRouteOption(
      totalTimeMinutes: 30,
      fare: 1400,
      transferCount: 1,
      totalWalkMeters: 300,
      modes: const [TransitLegType.subway],
      legs: [
        _leg(TransitLegType.walk, const []),
        _leg(TransitLegType.subway, _straight),
        _leg(TransitLegType.walk, const []),
      ],
      mapObj: mapObj,
    );

/// 통신만 가짜로 바꿔 실제 조회 절차를 그대로 태운다. 불린 요청을 남긴다.
Future<List<TransitRouteLeg>?> _call(
  TransitRouteOption option,
  Future<http.Response> Function(http.Request request) handler, {
  List<http.Request>? seen,
}) {
  return http.runWithClient(
    () => TransitRouteOptionsService.instance.fetchLaneLegs(option),
    () => MockClient((request) {
      seen?.add(request);
      return handler(request);
    }),
  );
}

void main() {
  group('fetchLaneLegs', () {
    test('mapObj 와 구간 종류를 본문으로 보내고, 받은 좌표를 그 구간에 입힌다', () async {
      final seen = <http.Request>[];
      final legs = await _call(
        _option(),
        (_) async => _json({
          'status': 'ok',
          'geometries': [
            [],
            [
              [37.5665, 126.9780],
              [37.5600, 126.9700],
              [37.5228, 126.9227],
            ],
            [],
          ],
        }),
        seen: seen,
      );

      final request = seen.single;
      expect(request.method, 'POST');
      expect(request.url.path, endsWith('/api/v1/transit/routes/lane'));
      expect(jsonDecode(request.body), {
        'map_obj': '18:2:132:136@204:2:917:915',
        'types': ['walk', 'subway', 'walk'],
      });

      expect(legs, isNotNull);
      expect(legs!, hasLength(3));
      expect(legs[1].geometry, hasLength(3));
      // 도보 자리는 원래(빈) 좌표 그대로다.
      expect(legs[0].geometry, isEmpty);
      expect(legs[2].geometry, isEmpty);
      // 좌표 말고는 그대로다.
      expect(legs[1].lineName, '2호선');
      expect(legs[1].stopNames, ['시청', '충정로', '여의도']);
    });

    test('서버가 unavailable 이면 null — 직선 유지', () async {
      final legs = await _call(
        _option(),
        (_) async => _json({'status': 'unavailable', 'geometries': []}),
      );
      expect(legs, isNull);
    });

    test('서버 오류(500)여도 예외 없이 null', () async {
      final legs = await _call(_option(), (_) async => _json({}, status: 500));
      expect(legs, isNull);
    });

    test('좌표 목록 길이가 구간 수와 다르면 null — 엉뚱한 구간에 입히지 않는다', () async {
      final legs = await _call(
        _option(),
        (_) async => _json({
          'status': 'ok',
          'geometries': [
            [
              [37.5, 126.9],
              [37.6, 127.0],
            ],
          ],
        }),
      );
      expect(legs, isNull);
    });

    test('한 점뿐인 자리는 원래 좌표를 두고, 바뀐 게 없으면 null', () async {
      final legs = await _call(
        _option(),
        (_) async => _json({
          'status': 'ok',
          'geometries': [
            [],
            [
              [37.5, 126.9],
            ],
            [],
          ],
        }),
      );
      expect(legs, isNull);
    });

    test('mapObj 가 없는 후보는 서버를 부르지 않는다', () async {
      final seen = <http.Request>[];
      final legs = await _call(
        _option(mapObj: null),
        (_) async => _json({'status': 'ok', 'geometries': []}),
        seen: seen,
      );
      expect(legs, isNull);
      expect(seen, isEmpty);
    });
  });
}
