import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/features/mobility/screens/bike_scooter_location_screen.dart';

/// 서버가 준 대여소 한 줄을 화면 모델로 옮기는 짝짓기를 고정한다.
///
/// 이름이 서버와 화면에서 다르다. 어긋나면 대여소가 전부 0 으로 보이는데,
/// 그 모습은 "자전거가 없는 대여소" 와 구분되지 않아 화면만 봐서는 모른다.
void main() {
  test('서버 응답의 이름을 화면 모델로 옮긴다', () {
    final station = DdallengiStation.fromServer(const {
      'station_id': 'ST-123',
      'name': '서울숲역 2번출구',
      'rack_total': 15,
      'parking_bike_total': 4,
      'lat': 37.5445,
      'lng': 127.0374,
    });

    expect(station.stationId, 'ST-123');
    expect(station.stationName, '서울숲역 2번출구');
    expect(station.rackTotCnt, 15);
    expect(station.parkingBikeTotCnt, 4);
    expect(station.lat, 37.5445);
    expect(station.lng, 127.0374);
  });

  test('빠진 값은 0 과 빈 문자열로 둔다', () {
    // 발급처가 일부 항목을 비워 보내는 경우가 있다. 그때 화면이 죽지 않아야 한다.
    final station = DdallengiStation.fromServer(const {'station_id': 'ST-9'});

    expect(station.stationName, '');
    expect(station.rackTotCnt, 0);
    expect(station.lat, 0);
  });

  test('거리 계산은 좌표 차이를 미터로 준다', () {
    // 5km 밖을 걸러 내는 데 쓰는 값이라, 단위가 어긋나면 지도에 아무것도
    // 뜨지 않거나 전국이 다 뜬다.
    final station = DdallengiStation.fromServer(const {
      'station_id': 'ST-1',
      'lat': 37.5665,
      'lng': 126.9780,
    });

    expect(station.distanceTo(37.5665, 126.9780), lessThan(1));
    // 위도 0.01도는 약 1.1km 다.
    expect(station.distanceTo(37.5765, 126.9780), inInclusiveRange(1000, 1200));
  });
}
