// 따릉이 대여소 조회가 서버 표기를 화면이 쓰는 형태로 옮기는지 본다.
//
// 서버는 필드 이름을 밑줄로 끊어 준다(station_id, parking_bike_total 등).
// 이름이 하나만 어긋나도 값이 조용히 비고, 대여소는 이름 없는 점으로 지도에
// 남는다. 조회가 실패하는 쪽은 예외를 내지 않고 빈 목록으로 내려앉는다 —
// 지도는 그대로 두고 마커만 비우려는 것이라, 이 성질도 함께 붙잡아 둔다.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:map_service_client/core/api/bike_station_api_service.dart';

/// 본문을 utf-8 로 실어 보낸다. 조회 쪽이 본문 바이트를 utf-8 로 읽기 때문에
/// 문자표를 밝히지 않으면 대여소 이름이 깨진 채로 비교하게 된다.
http.Response _json(Object body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// 본문 문자열을 그대로 실어 보낸다. 형태가 망가진 응답을 흉내 낼 때 쓴다.
http.Response _raw(String body, {int status = 200}) => http.Response(
  body,
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// 통신만 가짜로 바꿔 실제 조회 절차를 그대로 태운다.
Future<List<DdallengiStation>> _call(
  Future<http.Response> Function(http.Request request) handler, {
  double latitude = 37.5665,
  double longitude = 126.9780,
  int? radiusMeters,
}) {
  return http.runWithClient(
    () => radiusMeters == null
        ? BikeStationApiService.instance.fetchStations(
            latitude: latitude,
            longitude: longitude,
          )
        : BikeStationApiService.instance.fetchStations(
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radiusMeters,
          ),
    () => MockClient(handler),
  );
}

void main() {
  group('DdallengiStation.fromJson', () {
    test('밑줄로 끊긴 서버 표기를 그대로 옮긴다', () {
      final station = DdallengiStation.fromJson(const {
        'station_id': 'ST-1234',
        'name': '광화문역 2번출구 앞',
        'rack_total': 20,
        'parking_bike_total': 7,
        'lat': 37.5715,
        'lng': 126.9769,
      });

      expect(station.stationId, 'ST-1234');
      expect(station.stationName, '광화문역 2번출구 앞');
      expect(station.rackTotCnt, 20);
      expect(station.parkingBikeTotCnt, 7);
      expect(station.lat, 37.5715);
      expect(station.lng, 126.9769);
    });

    test('필드가 빠져도 열리고 기본값으로 내려앉는다', () {
      final station = DdallengiStation.fromJson(const {});

      expect(station.stationId, isEmpty);
      expect(station.stationName, isEmpty);
      expect(station.rackTotCnt, 0);
      expect(station.parkingBikeTotCnt, 0);
      expect(station.lat, 0);
      expect(station.lng, 0);
    });

    test('거치대 수가 실수로 와도 정수로 옮긴다', () {
      final station = DdallengiStation.fromJson(const {
        'rack_total': 20.0,
        'parking_bike_total': 7.0,
      });

      expect(station.rackTotCnt, 20);
      expect(station.parkingBikeTotCnt, 7);
    });

    test('좌표가 정수로 와도 실수로 옮긴다', () {
      final station = DdallengiStation.fromJson(const {'lat': 37, 'lng': 127});

      expect(station.lat, 37.0);
      expect(station.lng, 127.0);
    });

    test('대여 가능 수가 0 이어도 빈 값과 구분되지 않는 자리에 놓이지 않는다', () {
      // 자전거가 한 대도 없는 대여소와 거치대가 없는 응답은 둘 다 0 이지만,
      // 거치대 수가 남아 있어 화면이 "0/20" 으로 구분해 보여 줄 수 있다.
      final station = DdallengiStation.fromJson(const {
        'rack_total': 20,
        'parking_bike_total': 0,
      });

      expect(station.parkingBikeTotCnt, 0);
      expect(station.rackTotCnt, 20);
    });
  });

  group('distanceTo', () {
    DdallengiStation stationAt(double lat, double lng) =>
        DdallengiStation.fromJson({'lat': lat, 'lng': lng});

    test('같은 자리는 0 m 다', () {
      expect(stationAt(37.5665, 126.9780).distanceTo(37.5665, 126.9780), 0);
    });

    test('위도 1도 차이는 약 111 km 다', () {
      // 경도와 달리 위도 1도는 위치에 상관없이 일정하다. 반지름 상수와 각도
      // 변환이 맞물려 있는지 여기서 드러난다.
      expect(stationAt(38.5665, 126.9780).distanceTo(37.5665, 126.9780), 111195);
    });

    test('서울시청에서 서울역까지 약 1.46 km 로 잰다', () {
      final seoulStation = stationAt(37.5547, 126.9707);

      expect(seoulStation.distanceTo(37.5665, 126.9780), 1461);
    });

    test('경도 차이도 거리로 잡는다', () {
      expect(stationAt(37.5665, 126.9880).distanceTo(37.5665, 126.9780), 881);
    });

    test('어느 쪽에서 재도 같은 값이 나온다', () {
      final a = stationAt(37.5665, 126.9780);
      final b = stationAt(37.5547, 126.9707);

      expect(a.distanceTo(b.lat, b.lng), b.distanceTo(a.lat, a.lng));
    });

    test('가까운 대여소가 먼 대여소보다 작은 값을 갖는다', () {
      // 화면은 이 값으로 목록을 정렬한다. 크기 관계가 뒤집히면 먼 대여소가
      // 위로 올라온다.
      final near = stationAt(37.5670, 126.9785);
      final far = stationAt(37.6000, 127.0500);

      expect(
        near.distanceTo(37.5665, 126.9780),
        lessThan(far.distanceTo(37.5665, 126.9780)),
      );
    });
  });

  group('fetchStations — 받아 온 목록', () {
    test('서버가 준 대여소를 그대로 옮긴다', () async {
      final stations = await _call((_) async {
        return _json({
          'stations': [
            {
              'station_id': 'ST-1',
              'name': '시청역 3번출구',
              'rack_total': 15,
              'parking_bike_total': 4,
              'lat': 37.5652,
              'lng': 126.9770,
            },
            {
              'station_id': 'ST-2',
              'name': '을지로입구역 4번출구',
              'rack_total': 10,
              'parking_bike_total': 0,
              'lat': 37.5660,
              'lng': 126.9820,
            },
          ],
        });
      });

      expect(stations, hasLength(2));
      expect(stations.first.stationId, 'ST-1');
      expect(stations.first.stationName, '시청역 3번출구');
      expect(stations.first.parkingBikeTotCnt, 4);
      expect(stations.last.stationName, '을지로입구역 4번출구');
    });

    test('한글 대여소 이름이 깨지지 않고 그대로 올라온다', () async {
      final stations = await _call((_) async {
        return _json({
          'stations': [
            {'station_id': 'ST-3', 'name': '뚝섬유원지역 1번출구 앞'},
          ],
        });
      });

      expect(stations.single.stationName, '뚝섬유원지역 1번출구 앞');
    });

    test('목록 안의 객체 아닌 항목은 버린다', () async {
      final stations = await _call((_) async {
        return _json({
          'stations': [
            {'station_id': 'ST-1'},
            'garbage',
            42,
            null,
          ],
        });
      });

      expect(stations, hasLength(1));
      expect(stations.single.stationId, 'ST-1');
    });

    test('서비스 지역 밖이면 빈 목록이 온다', () async {
      final stations = await _call(
        (_) async => _json(const {'stations': []}),
        latitude: 35.1796,
        longitude: 129.0756,
      );

      expect(stations, isEmpty);
    });
  });

  group('fetchStations — 실패해도 지도를 막지 않는다', () {
    test('200 이 아니면 예외 없이 빈 목록이다', () async {
      expect(await _call((_) async => _json(const {}, status: 500)), isEmpty);
      expect(await _call((_) async => _json(const {}, status: 404)), isEmpty);
    });

    test('통신이 끊겨도 예외를 밖으로 내지 않는다', () async {
      expect(
        await _call((_) async => throw http.ClientException('연결 끊김')),
        isEmpty,
      );
    });

    test('본문이 JSON 이 아니어도 빈 목록이다', () async {
      expect(await _call((_) async => _raw('<html>502</html>')), isEmpty);
    });

    test('본문이 객체가 아니라 배열로 와도 빈 목록이다', () async {
      expect(await _call((_) async => _raw('[]')), isEmpty);
    });

    test('숫자 자리에 문자열이 섞여 오면 그 대여소만 빠지고 나머지는 남는다', () async {
      // 한 곳의 값 하나가 어긋났다고 지도를 통째로 비우지 않는다. 못 읽은
      // 곳만 빼고 나머지는 그대로 보여 준다.
      final stations = await _call((_) async {
        return _json({
          'stations': [
            {'station_id': 'ST-1', 'name': '멀쩡한 대여소', 'rack_total': 15},
            {'station_id': 'ST-2', 'rack_total': '스무 개'},
            {'station_id': 'ST-3', 'name': '또 다른 대여소', 'rack_total': 20},
          ],
        });
      });

      expect(stations.map((s) => s.stationId), ['ST-1', 'ST-3']);
    });

    test('stations 가 없거나 목록이 아니면 빈 목록이다', () async {
      expect(await _call((_) async => _json(const {})), isEmpty);
      expect(
        await _call((_) async => _json(const {'stations': 'not-a-list'})),
        isEmpty,
      );
      expect(await _call((_) async => _json(const {'stations': null})), isEmpty);
    });
  });

  group('fetchStations — 요청', () {
    test('좌표와 반경을 실어 보낸다', () async {
      Uri? sent;
      await _call(
        (request) async {
          sent = request.url;
          return _json(const {'stations': []});
        },
        latitude: 37.5665,
        longitude: 126.9780,
        radiusMeters: 1200,
      );

      expect(sent, isNotNull);
      expect(sent!.path, '/api/v1/mobility/bike-stations');
      expect(sent!.queryParameters, {
        'lat': '37.5665',
        'lng': '126.978',
        'radiusM': '1200',
      });
    });

    test('반경을 주지 않으면 화면이 거르는 범위와 같은 기본값을 쓴다', () async {
      Uri? sent;
      await _call((request) async {
        sent = request.url;
        return _json(const {'stations': []});
      });

      expect(BikeStationApiService.defaultRadiusMeters, 5000);
      expect(sent!.queryParameters['radiusM'], '5000');
    });

    test('앱은 인증키를 싣지 않는다 — 발급처는 서버가 부른다', () async {
      late http.Request sent;
      await _call((request) async {
        sent = request;
        return _json(const {'stations': []});
      });

      expect(sent.url.queryParameters.keys, ['lat', 'lng', 'radiusM']);
      expect(
        sent.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('authorization')),
      );
    });

    test('평문 http 로 나가는 발급처를 직접 부르지 않는다', () async {
      // 예전에는 앱이 발급처를 직접 불렀고 그 주소가 https 를 받지 않았다.
      // 지금은 서버 주소 하나만 본다.
      late Uri sent;
      await _call((request) async {
        sent = request.url;
        return _json(const {'stations': []});
      });

      expect(sent.host, isNot(contains('seoul.go.kr')));
      expect(sent.path, startsWith('/api/v1/'));
    });
  });
}
