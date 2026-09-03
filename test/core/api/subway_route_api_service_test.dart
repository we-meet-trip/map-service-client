// 지하철 경로 조회가 결과를 세 갈래로 갈라 돌려주는지 본다.
//
// 서버는 같은 200 응답 안에서 status 로 결과를 나눈다. 경로를 찾은 경우,
// 지하철만으로는 갈 수 없는 경우, 지금은 알아볼 수 없는 경우다. 화면은 이
// 셋을 서로 다른 문구로 보여 주므로 — 없음은 "경로가 없어요", 못 알아봄은
// "불러오지 못했어요" — 가운데가 하나로 뭉치면 서버가 잠깐 흔들린 것이
// "지하철로는 못 간다"로 표시된다. 셋이 갈라져 있는지 여기서 붙잡아 둔다.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:map_service_client/core/api/subway_route_api_service.dart';

/// 본문을 utf-8 로 실어 보낸다. 조회 쪽이 본문 바이트를 utf-8 로 읽기 때문에
/// 문자표를 밝히지 않으면 한글이 깨진 채로 비교하게 된다.
http.Response _json(Object body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// 통신만 가짜로 바꿔 실제 조회 절차를 그대로 태운다.
Future<SubwayRoute?> _call(
  Future<http.Response> Function(http.Request request) handler, {
  double startLat = 37.5665,
  double startLng = 126.9780,
  double endLat = 37.4979,
  double endLng = 127.0276,
}) {
  return http.runWithClient(
    () => SubwayRouteApiService.instance.findFastestSubwayRoute(
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
    ),
    () => MockClient(handler),
  );
}

/// status 만 바꿔 가며 부를 때 쓰는 최소 본문. status 를 주지 않으면 그 자리
/// 자체가 없는 응답이 된다.
Future<SubwayRoute?> _callWithStatus(String? status) {
  final body = <String, Object>{
    'route': {'total_time_min': 30, 'fare': 1400},
  };
  if (status != null) body['status'] = status;
  return _call((_) async => _json(body));
}

void main() {
  group('findFastestSubwayRoute — 세 갈래 응답', () {
    test('ok 면 경로를 돌려준다', () async {
      final route = await _call((_) async {
        return _json({
          'status': 'ok',
          'route': {
            'total_time_min': 42,
            'fare': 1550,
            'transfer_count': 1,
            'total_walk_m': 380,
            'steps': [
              {
                'type': 'walk',
                'start_name': '출발지',
                'end_name': '시청역',
                'section_time_min': 5,
              },
              {
                'type': 'subway',
                'line_name': '2호선',
                'start_name': '시청역',
                'end_name': '교대역',
                'section_time_min': 30,
                'station_count': 12,
              },
            ],
          },
        });
      });

      expect(route, isNotNull);
      expect(route!.totalTimeMinutes, 42);
      expect(route.fare, 1550);
      expect(route.transferCount, 1);
      expect(route.totalWalkMeters, 380);
      expect(route.steps, hasLength(2));
      expect(route.steps.last.lineName, '2호선');
    });

    test('not_found 면 예외 없이 null 이다 — 갈 수 있는 길이 없다', () async {
      expect(await _callWithStatus('not_found'), isNull);
    });

    test('unavailable 이면 예외를 낸다 — 지금은 알아볼 수 없다', () async {
      expect(_callWithStatus('unavailable'), throwsA(isA<Exception>()));
    });

    test('모르는 status 는 알아볼 수 없는 쪽으로 다룬다', () async {
      expect(_callWithStatus('weird'), throwsA(isA<Exception>()));
    });

    test('status 가 아예 없어도 알아볼 수 없는 쪽으로 다룬다', () async {
      expect(_callWithStatus(null), throwsA(isA<Exception>()));
    });

    test('길이 없는 것과 못 알아본 것은 서로 다른 결과로 남는다', () async {
      // 화면이 두 상황에 다른 문구를 건다. 둘이 같은 모양으로 나오면
      // 잠깐 흔들린 서버가 "지하철로는 못 간다"로 표시된다.
      final notFound = await _callWithStatus('not_found');
      Object? thrown;
      try {
        await _callWithStatus('unavailable');
      } catch (error) {
        thrown = error;
      }

      expect(notFound, isNull);
      expect(thrown, isNotNull);
    });
  });

  group('findFastestSubwayRoute — 실패한 응답', () {
    test('200 이 아니면 예외를 내고 상태 코드를 문구에 싣는다', () async {
      expect(
        _call((_) async => _json({'status': 'ok'}, status: 500)),
        throwsA(
          isA<Exception>().having((e) => e.toString(), '문구', contains('500')),
        ),
      );
    });

    test('찾을 수 없다는 응답이 404 로 와도 예외다 — 본문의 not_found 와 다르다', () async {
      // 상태 코드로 온 404 는 본문을 읽기 전에 끊긴다. 이걸 null 로 삼키면
      // 통로가 잘못 놓인 것이 "경로 없음"으로 보인다.
      expect(
        _call((_) async => _json({'status': 'not_found'}, status: 404)),
        throwsA(isA<Exception>()),
      );
    });

    test('ok 인데 route 가 없으면 예외로 간다', () async {
      expect(
        _call((_) async => _json({'status': 'ok'})),
        throwsA(isA<Exception>()),
      );
    });

    test('ok 인데 route 가 객체가 아니면 예외로 간다', () async {
      expect(
        _call((_) async => _json({'status': 'ok', 'route': 'not-an-object'})),
        throwsA(isA<Exception>()),
      );
    });

    test('통신 자체가 끊기면 그대로 밖으로 나간다 — 조용히 없음이 되지 않는다', () async {
      expect(
        _call((_) async => throw http.ClientException('연결 끊김')),
        throwsA(isA<http.ClientException>()),
      );
    });

    test('값의 형태가 어긋난 경로도 없음이 아니라 못 불러옴으로 나간다', () async {
      // 수치 자리에 문자열이 오면 옮기는 중에 끊긴다. 이 실패가 null 로
      // 새어 나가면 응답이 망가진 것이 "지하철로는 못 간다"로 표시된다.
      expect(
        _call(
          (_) async => _json({
            'status': 'ok',
            'route': {'total_time_min': '사십이 분'},
          }),
        ),
        throwsA(anything),
      );
    });
  });

  group('findFastestSubwayRoute — 요청', () {
    test('출발·도착 좌표를 이름 그대로 실어 보낸다', () async {
      Uri? sent;
      await _call((request) async {
        sent = request.url;
        return _json({'status': 'not_found'});
      }, startLat: 37.5665, startLng: 126.9780, endLat: 37.4979, endLng: 127.0276);

      expect(sent, isNotNull);
      expect(sent!.path, '/api/v1/transit/subway');
      expect(sent!.queryParameters, {
        'startLat': '37.5665',
        'startLng': '126.978',
        'endLat': '37.4979',
        'endLng': '127.0276',
      });
    });

    test('앱은 인증키를 싣지 않는다 — 발급처는 서버가 부른다', () async {
      late http.Request sent;
      await _call((request) async {
        sent = request;
        return _json({'status': 'not_found'});
      });

      final query = sent.url.queryParameters.keys;
      expect(query, ['startLat', 'startLng', 'endLat', 'endLng']);
      expect(
        sent.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('authorization')),
      );
    });

    test('한글 역 이름이 깨지지 않고 그대로 올라온다', () async {
      final route = await _call((_) async {
        return _json({
          'status': 'ok',
          'route': {
            'total_time_min': 10,
            'steps': [
              {
                'type': 'subway',
                'line_name': '수인분당선',
                'start_name': '왕십리역',
                'end_name': '선릉역',
                'section_time_min': 10,
              },
            ],
          },
        });
      });

      expect(route!.steps.single.lineName, '수인분당선');
      expect(route.steps.single.startName, '왕십리역');
      expect(route.steps.single.endName, '선릉역');
    });
  });

  group('SubwayRoute.fromJson', () {
    test('서버가 준 값을 그대로 옮긴다', () {
      final route = SubwayRoute.fromJson({
        'total_time_min': 55,
        'fare': 1600,
        'transfer_count': 2,
        'total_walk_m': 720,
        'steps': [
          {'type': 'walk', 'section_time_min': 4},
        ],
      });

      expect(route.totalTimeMinutes, 55);
      expect(route.fare, 1600);
      expect(route.transferCount, 2);
      expect(route.totalWalkMeters, 720);
      expect(route.steps, hasLength(1));
    });

    test('빠진 수치는 0 으로 두어 화면이 열린다', () {
      final route = SubwayRoute.fromJson(const {});

      expect(route.totalTimeMinutes, 0);
      expect(route.fare, 0);
      expect(route.transferCount, 0);
      expect(route.totalWalkMeters, 0);
      expect(route.steps, isEmpty);
    });

    test('수치가 실수로 와도 정수로 옮긴다', () {
      final route = SubwayRoute.fromJson({
        'total_time_min': 42.0,
        'fare': 1550.0,
        'transfer_count': 1.0,
        'total_walk_m': 380.0,
      });

      expect(route.totalTimeMinutes, 42);
      expect(route.fare, 1550);
      expect(route.transferCount, 1);
      expect(route.totalWalkMeters, 380);
    });

    test('steps 가 목록이 아니면 빈 목록으로 다룬다', () {
      expect(SubwayRoute.fromJson({'steps': 'not-a-list'}).steps, isEmpty);
      expect(SubwayRoute.fromJson({'steps': null}).steps, isEmpty);
    });

    test('steps 안의 객체 아닌 항목은 버린다', () {
      final route = SubwayRoute.fromJson({
        'steps': [
          {'type': 'subway', 'start_name': '시청역'},
          'garbage',
          42,
          null,
        ],
      });

      expect(route.steps, hasLength(1));
      expect(route.steps.single.startName, '시청역');
    });
  });

  group('SubwayRouteStep.fromJson', () {
    test('이동 수단을 종류별로 갈라 옮긴다', () {
      expect(
        SubwayRouteStep.fromJson(const {'type': 'subway'}).type,
        SubwayStepType.subway,
      );
      expect(
        SubwayRouteStep.fromJson(const {'type': 'bus'}).type,
        SubwayStepType.bus,
      );
      expect(
        SubwayRouteStep.fromJson(const {'type': 'walk'}).type,
        SubwayStepType.walk,
      );
    });

    test('모르는 수단과 빠진 수단은 도보로 둔다', () {
      expect(
        SubwayRouteStep.fromJson(const {'type': 'tram'}).type,
        SubwayStepType.walk,
      );
      expect(SubwayRouteStep.fromJson(const {}).type, SubwayStepType.walk);
    });

    test('구간 정보를 그대로 옮긴다', () {
      final step = SubwayRouteStep.fromJson(const {
        'type': 'subway',
        'line_name': '9호선',
        'start_name': '노량진역',
        'end_name': '고속터미널역',
        'section_time_min': 14,
        'station_count': 6,
      });

      expect(step.lineName, '9호선');
      expect(step.startName, '노량진역');
      expect(step.endName, '고속터미널역');
      expect(step.sectionTimeMinutes, 14);
      expect(step.stationCount, 6);
    });

    test('역 이름이 없으면 빈 문자열이 되어 호출 측이 걸러 낼 수 있다', () {
      final step = SubwayRouteStep.fromJson(const {'type': 'walk'});

      expect(step.startName, isEmpty);
      expect(step.endName, isEmpty);
      expect(step.sectionTimeMinutes, 0);
    });

    test('도보 구간은 노선도 정차역 수도 없이 온다', () {
      // 없음과 0 은 다르다. 0 으로 채우면 도보 구간에 "0개 역"이 붙는다.
      final step = SubwayRouteStep.fromJson(const {
        'type': 'walk',
        'start_name': '출발지',
        'end_name': '시청역',
        'section_time_min': 5,
      });

      expect(step.lineName, isNull);
      expect(step.stationCount, isNull);
    });

    test('구간 수치가 실수로 와도 정수로 옮긴다', () {
      final step = SubwayRouteStep.fromJson(const {
        'type': 'subway',
        'section_time_min': 14.0,
        'station_count': 6.0,
      });

      expect(step.sectionTimeMinutes, 14);
      expect(step.stationCount, 6);
    });
  });
}
