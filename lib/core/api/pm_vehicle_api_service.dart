import 'dart:math';

import 'api_client.dart';

/// 공유 킥보드 한 대.
class PmVehicle {
  /// 사업자 이름(예: "SWING"). 마커 색을 정하는 데 쓴다.
  final String providerName;

  /// 기기 식별자. 대여할 때 어느 기기인지 가리킨다.
  final String deviceId;

  /// 남은 배터리(%). 발급처가 안 주는 사업자가 있어 비어 있을 수 있다.
  final int? batteryLevel;

  /// 기기 종류 표기(예: "전동킥보드", "전기자전거").
  final String vehicleType;

  final double lat;
  final double lng;

  const PmVehicle({
    required this.providerName,
    required this.deviceId,
    required this.vehicleType,
    required this.lat,
    required this.lng,
    this.batteryLevel,
  });

  factory PmVehicle.fromJson(Map<String, dynamic> json) => PmVehicle(
        providerName: json['provider'] as String? ?? '',
        deviceId: json['device_id'] as String? ?? '',
        vehicleType: json['vehicle_type'] as String? ?? '전동킥보드',
        lat: (json['lat'] as num?)?.toDouble() ?? 0,
        lng: (json['lng'] as num?)?.toDouble() ?? 0,
        batteryLevel: (json['battery_level'] as num?)?.toInt(),
      );

  /// 자전거인지. 같은 발급처가 킥보드와 전기자전거를 함께 준다.
  bool get isBike => vehicleType.contains('자전거');

  int distanceTo(double userLat, double userLng) {
    const r = 6371000.0;
    final dLat = (lat - userLat) * pi / 180;
    final dLng = (lng - userLng) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(userLat * pi / 180) *
            cos(lat * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return (r * 2 * atan2(sqrt(a), sqrt(1 - a))).round();
  }
}

/// 공유 킥보드 위치를 가져오는 통로.
///
/// 발급처(국토교통부 퍼스널모빌리티)는 사업자별로 따로 물어야 하고 키가
/// 필요해서, 앱이 직접 부르지 않고 서버를 거친다. 서버가 사업자들을 한 번에
/// 훑어 합쳐 준다.
///
/// **주변에 기기가 없는 것과 조회에 실패한 것은 다르다.** 앞은 정상이고
/// 뒤는 나중에 다시 시도해야 하므로, 화면이 두 경우에 다른 문구를 쓸 수
/// 있도록 갈라서 돌려준다.
class PmVehicleApiService {
  PmVehicleApiService._();

  static final PmVehicleApiService instance = PmVehicleApiService._();

  static const _timeout = Duration(seconds: 15);

  /// 기본 반경(m). 걸어가서 타는 것이라 대여소보다 좁게 둔다.
  static const defaultRadiusMeters = 1000;

  /// 좌표 주변의 킥보드를 받는다.
  ///
  /// 반환값이 null 이면 조회 자체가 안 된 것이고, 빈 목록이면 주변에 기기가
  /// 없다는 뜻이다.
  Future<List<PmVehicle>?> fetchVehicles({
    required double latitude,
    required double longitude,
    int radiusMeters = defaultRadiusMeters,
  }) async {
    try {
      final body = await ApiClient.instance.get(
        '/api/v1/mobility/pm-vehicles',
        query: {
          'lat': '$latitude',
          'lng': '$longitude',
          'radiusM': '$radiusMeters',
        },
        timeout: _timeout,
      );
      // 서버는 발급처가 통째로 응답하지 않은 경우를 status 로 알려 준다.
      // 그때의 빈 목록은 "주변에 없다"가 아니라 "알 수 없다"이다.
      if (body['status'] == 'unavailable') return null;
      final raw = body['vehicles'];
      if (raw is! List) return null;
      // 한 대씩 읽는다. 한 대의 값 하나가 어긋나 목록 전체가 사라지는 것보다
      // 못 읽은 한 대만 빠지는 편이 낫다.
      final out = <PmVehicle>[];
      for (final item in raw) {
        if (item is! Map<String, dynamic>) continue;
        try {
          out.add(PmVehicle.fromJson(item));
        } catch (_) {
          continue;
        }
      }
      return out;
    } catch (_) {
      return null;
    }
  }
}
