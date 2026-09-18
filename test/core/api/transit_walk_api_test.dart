// 경로 지도의 도보 연결선 조회가 "실패하면 직선 유지"를 지키는지 본다.
//
// 연결선 보행 경로는 부가 정보다. 서버가 못 주거나 모양이 어긋나면 화면은
// 회색 직선을 그대로 두면 된다 — 예외가 새어 나가거나, 어긋난 경로가 엉뚱한
// 연결선에 입혀지면 안 된다.
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

const _twoSegments = <(List<double>, List<double>)>[
  ([37.5665, 126.9780], [37.5657, 126.9769]),
  ([37.5219, 126.9243], [37.5228, 126.9227]),
];

Future<List<List<List<double>>?>?> _call(
  List<(List<double>, List<double>)> segments,
  Future<http.Response> Function(http.Request request) handler, {
  List<http.Request>? seen,
}) {
  return http.runWithClient(
    () => TransitRouteOptionsService.instance.fetchWalkPaths(segments),
    () => MockClient((request) {
      seen?.add(request);
      return handler(request);
    }),
  );
}

void main() {
  group('fetchWalkPaths', () {
    test('양 끝 좌표를 본문으로 보내고, 받은 경로를 같은 순서로 돌려준다', () async {
      final seen = <http.Request>[];
      final paths = await _call(
        _twoSegments,
        (_) async => _json({
          'status': 'ok',
          'paths': [
            [
              [37.5665, 126.9780],
              [37.5661, 126.9775],
              [37.5657, 126.9769],
            ],
            [],
          ],
        }),
        seen: seen,
      );

      final request = seen.single;
      expect(request.method, 'POST');
      expect(request.url.path, endsWith('/api/v1/transit/routes/walk'));
      expect(jsonDecode(request.body), {
        'segments': [
          {
            'start_lat': 37.5665,
            'start_lng': 126.9780,
            'end_lat': 37.5657,
            'end_lng': 126.9769,
          },
          {
            'start_lat': 37.5219,
            'start_lng': 126.9243,
            'end_lat': 37.5228,
            'end_lng': 126.9227,
          },
        ],
      });

      expect(paths, isNotNull);
      expect(paths!, hasLength(2));
      expect(paths[0], hasLength(3));
      // 서버가 못 준 자리는 null — 그 연결선만 직선으로 둔다.
      expect(paths[1], isNull);
    });

    test('서버가 unavailable 이면 null', () async {
      final paths = await _call(
        _twoSegments,
        (_) async => _json({'status': 'unavailable', 'paths': []}),
      );
      expect(paths, isNull);
    });

    test('서버 오류(500)여도 예외 없이 null', () async {
      final paths = await _call(_twoSegments, (_) async => _json({}, status: 500));
      expect(paths, isNull);
    });

    test('경로 수가 요청 수와 다르면 null — 엉뚱한 연결선에 입히지 않는다', () async {
      final paths = await _call(
        _twoSegments,
        (_) async => _json({
          'status': 'ok',
          'paths': [
            [
              [37.5, 126.9],
              [37.6, 127.0],
            ],
          ],
        }),
      );
      expect(paths, isNull);
    });

    test('연결선이 없거나 20개를 넘으면 서버를 부르지 않는다', () async {
      final seen = <http.Request>[];
      final tooMany = List.generate(21, (_) => _twoSegments.first);
      expect(await _call(const [], (_) async => _json({}), seen: seen), isNull);
      expect(await _call(tooMany, (_) async => _json({}), seen: seen), isNull);
      expect(seen, isEmpty);
    });
  });
}
