import 'api_client.dart';

/// 통합 길찾기 경로 후보에 등장하는 이동수단.
enum TransitLegType { walk, subway, bus }

/// 통합 길찾기 경로 후보의 한 구간.
class TransitRouteLeg {
  final TransitLegType type;
  final String? lineName;
  final String startName;
  final String endName;
  final int sectionTimeMinutes;
  final int? stationCount;

  /// 지도에 그릴 [lat,lng] 좌표열. 좌표가 없는 순수 도보 연결 구간은 비어 있다.
  final List<List<double>> geometry;

  /// 지나는 역/정류장 이름(순서대로). geometry 와 같은 이유로 비어 있을 수
  /// 있다 — 버스는 가끔 이 목록이 비어 오고, 도보 연결 구간은 아예 없다.
  final List<String> stopNames;

  const TransitRouteLeg({
    required this.type,
    required this.startName,
    required this.endName,
    required this.sectionTimeMinutes,
    required this.geometry,
    required this.stopNames,
    this.lineName,
    this.stationCount,
  });

  factory TransitRouteLeg.fromJson(Map<String, dynamic> json) {
    final rawGeometry = json['geometry'];
    final rawStops = json['stops'];
    return TransitRouteLeg(
      type: switch (json['type'] as String?) {
        'subway' => TransitLegType.subway,
        'bus' => TransitLegType.bus,
        _ => TransitLegType.walk,
      },
      lineName: json['line_name'] as String?,
      startName: json['start_name'] as String? ?? '',
      endName: json['end_name'] as String? ?? '',
      sectionTimeMinutes: (json['section_time_min'] as num?)?.toInt() ?? 0,
      stationCount: (json['station_count'] as num?)?.toInt(),
      geometry: rawGeometry is List
          ? rawGeometry
              .whereType<List<dynamic>>()
              .map((p) => p.map((v) => (v as num).toDouble()).toList())
              .where((p) => p.length >= 2)
              .toList()
          : const [],
      stopNames: rawStops is List ? rawStops.whereType<String>().toList() : const [],
    );
  }
}

/// 통합 길찾기 경로 후보 한 건. 지하철 단독으로 거르지 않은 후보다.
class TransitRouteOption {
  final int totalTimeMinutes;
  final int fare;
  final int transferCount;
  final int totalWalkMeters;

  /// 이 경로에 실제 등장하는 이동수단(지하철·버스) 목록.
  final List<TransitLegType> modes;

  final List<TransitRouteLeg> legs;

  const TransitRouteOption({
    required this.totalTimeMinutes,
    required this.fare,
    required this.transferCount,
    required this.totalWalkMeters,
    required this.modes,
    required this.legs,
  });

  factory TransitRouteOption.fromJson(Map<String, dynamic> json) {
    final rawLegs = json['legs'];
    final rawModes = json['modes'];
    return TransitRouteOption(
      totalTimeMinutes: (json['total_time_min'] as num?)?.toInt() ?? 0,
      fare: (json['fare'] as num?)?.toInt() ?? 0,
      transferCount: (json['transfer_count'] as num?)?.toInt() ?? 0,
      totalWalkMeters: (json['total_walk_m'] as num?)?.toInt() ?? 0,
      modes: rawModes is List
          ? rawModes
              .whereType<String>()
              .map((m) => switch (m) {
                    'subway' => TransitLegType.subway,
                    'bus' => TransitLegType.bus,
                    _ => TransitLegType.walk,
                  })
              .toList()
          : const [],
      legs: rawLegs is List
          ? rawLegs
              .whereType<Map<String, dynamic>>()
              .map(TransitRouteLeg.fromJson)
              .toList()
          : const [],
    );
  }
}

/// 두 좌표 사이의 대중교통 경로를 가져오는 통로.
///
/// 지하철 전용 조회(SubwayRouteApiService)와 달리 버스 전용·혼합 경로까지
/// 소요시간 순으로 모두 받는다 — "카카오맵처럼 이동수단을 모두 보여주는" 화면용.
///
/// 발급처를 앱이 직접 부르지 않는다. 서버(BFF→hub)가 대신 호출하므로 앱에는
/// 인증키가 없다.
class TransitRouteOptionsService {
  TransitRouteOptionsService._();

  static final TransitRouteOptionsService instance =
      TransitRouteOptionsService._();

  /// "갈 수 있는 길이 없다"와 "지금은 알아볼 수 없다"는 화면에서 다른 문구로
  /// 보여야 한다. 그래서 앞은 빈 목록으로, 뒤는 예외로 갈라 돌려준다 — 둘을
  /// 합치면 서버가 잠깐 흔들린 것이 "갈 수 있는 경로가 없다"로 표시된다.
  Future<List<TransitRouteOption>> findRouteOptions({
    required double startLng,
    required double startLat,
    required double endLng,
    required double endLat,
  }) async {
    final Map<String, dynamic> body;
    try {
      body = await ApiClient.instance.get(
        '/api/v1/transit/routes',
        query: {
          'startLat': '$startLat',
          'startLng': '$startLng',
          'endLat': '$endLat',
          'endLng': '$endLng',
        },
      );
    } on ApiException catch (e) {
      throw Exception('경로 탐색에 실패했습니다. (${e.statusCode})');
    }

    switch (body['status'] as String?) {
      case 'ok':
        final raw = body['routes'];
        return raw is List
            ? raw
                .whereType<Map<String, dynamic>>()
                .map(TransitRouteOption.fromJson)
                .toList()
            : const [];
      case 'not_found':
        return const [];
      default:
        throw Exception('지금은 경로를 알아볼 수 없어요. 잠시 후 다시 시도해 주세요.');
    }
  }
}
