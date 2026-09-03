import 'dart:math';

import 'api_client.dart';

/// 따릉이 대여소 한 곳.
class DdallengiStation {
  final String stationId;
  final String stationName;
  final int rackTotCnt;
  final int parkingBikeTotCnt;
  final double lat;
  final double lng;

  const DdallengiStation({
    required this.stationId,
    required this.stationName,
    required this.rackTotCnt,
    required this.parkingBikeTotCnt,
    required this.lat,
    required this.lng,
  });

  factory DdallengiStation.fromJson(Map<String, dynamic> json) =>
      DdallengiStation(
        stationId: json['station_id'] as String? ?? '',
        stationName: json['name'] as String? ?? '',
        rackTotCnt: (json['rack_total'] as num?)?.toInt() ?? 0,
        parkingBikeTotCnt:
            (json['parking_bike_total'] as num?)?.toInt() ?? 0,
        lat: (json['lat'] as num?)?.toDouble() ?? 0,
        lng: (json['lng'] as num?)?.toDouble() ?? 0,
      );

  int distanceTo(double userLat, double userLng) {
    const R = 6371000.0;
    final dLat = (lat - userLat) * pi / 180;
    final dLng = (lng - userLng) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(userLat * pi / 180) *
            cos(lat * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return (R * 2 * atan2(sqrt(a), sqrt(1 - a))).round();
  }
}

/// 따릉이 대여소 현황을 가져오는 통로.
///
/// 예전에는 앱이 발급처를 직접 불렀다. 그때는 인증키가 앱에 실려 나갔고,
/// 그 발급처가 https 를 받지 않아 사용자가 접속한 망마다 키가 평문으로
/// 오갔다. 게다가 전체 목록을 한 번에 주지 않아 나눠 받아야 했는데, 앱이
/// 응답의 개수 필드를 전체 개수로 읽는 바람에 첫 장만 받고 멈춰서 실제로는
/// 일부만 보여 주고 있었다. 서버로 옮기면서 셋 다 사라졌다.
class BikeStationApiService {
  BikeStationApiService._();

  static final BikeStationApiService instance = BikeStationApiService._();

  static const _timeout = Duration(seconds: 15);

  /// 기본 반경(m). 화면이 마커를 거르는 범위와 맞춘다.
  static const defaultRadiusMeters = 5000;

  /// 좌표 주변의 대여소를 받는다.
  ///
  /// 서비스 지역이 서울이라 그 밖에서 물으면 빈 목록이 온다. 조회에 실패해도
  /// 빈 목록을 돌려준다 — 지도는 그대로 두고 마커만 비면 된다.
  ///
  /// 공통 통로로 보낸다. 이 경로는 서버에서 인증을 요구하는 쪽에 묶여 있어,
  /// 직접 보내면 토큰이 실리지 않아 인증이 켜지는 순간 조회가 통째로 막힌다.
  Future<List<DdallengiStation>> fetchStations({
    required double latitude,
    required double longitude,
    int radiusMeters = defaultRadiusMeters,
  }) async {
    try {
      final body = await ApiClient.instance.get(
        '/api/v1/mobility/bike-stations',
        query: {
          'lat': '$latitude',
          'lng': '$longitude',
          'radiusM': '$radiusMeters',
        },
        timeout: _timeout,
      );
      final raw = body['stations'];
      if (raw is! List) return const [];
      // 대여소는 하나씩 읽는다. 통째로 변환하면 한 곳의 값 하나만 형태가
      // 어긋나도 그 오류가 목록 전체를 삼켜, 멀쩡한 나머지까지 함께 사라진다.
      // 지도가 통째로 비는 것보다 못 읽은 한 곳만 빠지는 편이 낫다.
      final stations = <DdallengiStation>[];
      for (final item in raw) {
        if (item is! Map<String, dynamic>) continue;
        try {
          stations.add(DdallengiStation.fromJson(item));
        } catch (_) {
          continue;
        }
      }
      return stations;
    } catch (_) {
      return const [];
    }
  }
}
