import 'api_client.dart';

enum SubwayStepType { walk, subway, bus }

class SubwayRouteStep {
  final SubwayStepType type;
  final String? lineName;
  final String startName;
  final String endName;
  final int sectionTimeMinutes;
  final int? stationCount;

  const SubwayRouteStep({
    required this.type,
    required this.startName,
    required this.endName,
    required this.sectionTimeMinutes,
    this.lineName,
    this.stationCount,
  });

  factory SubwayRouteStep.fromJson(Map<String, dynamic> json) {
    return SubwayRouteStep(
      type: switch (json['type'] as String?) {
        'subway' => SubwayStepType.subway,
        'bus' => SubwayStepType.bus,
        _ => SubwayStepType.walk,
      },
      lineName: json['line_name'] as String?,
      startName: json['start_name'] as String? ?? '',
      endName: json['end_name'] as String? ?? '',
      sectionTimeMinutes: (json['section_time_min'] as num?)?.toInt() ?? 0,
      stationCount: (json['station_count'] as num?)?.toInt(),
    );
  }
}

class SubwayRoute {
  final int totalTimeMinutes;
  final int fare;
  final int transferCount;
  final int totalWalkMeters;
  final List<SubwayRouteStep> steps;

  const SubwayRoute({
    required this.totalTimeMinutes,
    required this.fare,
    required this.transferCount,
    required this.totalWalkMeters,
    required this.steps,
  });

  factory SubwayRoute.fromJson(Map<String, dynamic> json) {
    final steps = json['steps'];
    return SubwayRoute(
      totalTimeMinutes: (json['total_time_min'] as num?)?.toInt() ?? 0,
      fare: (json['fare'] as num?)?.toInt() ?? 0,
      transferCount: (json['transfer_count'] as num?)?.toInt() ?? 0,
      totalWalkMeters: (json['total_walk_m'] as num?)?.toInt() ?? 0,
      steps: steps is List
          ? steps
              .whereType<Map<String, dynamic>>()
              .map(SubwayRouteStep.fromJson)
              .toList()
          : const [],
    );
  }
}

/// 지하철 경로를 가져오는 통로.
///
/// 예전에는 앱이 발급처를 직접 불렀다. 그때는 인증키가 앱 꾸러미에 함께
/// 실려 나가서 꺼내 볼 수 있었고, 실행 중인 운영체제에 맞는 키를 골라 쓰는
/// 분기까지 앱이 들고 있어야 했다. 지금은 서버가 대신 부르므로 앱에는 키가
/// 없고 그 분기도 사라졌다.
class SubwayRouteApiService {
  SubwayRouteApiService._();

  static final SubwayRouteApiService instance = SubwayRouteApiService._();

  static const _timeout = Duration(seconds: 15);

  /// [startLng]/[startLat]에서 [endLng]/[endLat]까지의 지하철 단독 경로 중
  /// 가장 빠른 경로를 반환한다. 지하철만으로 갈 수 없으면 null을 반환한다.
  ///
  /// "갈 수 있는 길이 없다"와 "지금은 알아볼 수 없다"는 화면에서 다른 문구로
  /// 보여야 한다. 그래서 앞은 null 로, 뒤는 예외로 갈라 돌려준다 — 둘을
  /// 합치면 서버가 잠깐 흔들린 것이 "지하철로는 못 간다"로 표시된다.
  Future<SubwayRoute?> findFastestSubwayRoute({
    required double startLng,
    required double startLat,
    required double endLng,
    required double endLat,
  }) async {
    // 공통 통로로 보낸다. 이 경로는 서버에서 인증을 요구하는 쪽에 묶여 있어,
    // 직접 보내면 토큰이 실리지 않아 인증이 켜지는 순간 조회가 막힌다.
    final Map<String, dynamic> body;
    try {
      body = await ApiClient.instance.get(
        '/api/v1/transit/subway',
        query: {
          'startLat': '$startLat',
          'startLng': '$startLng',
          'endLat': '$endLat',
          'endLng': '$endLng',
        },
        timeout: _timeout,
      );
    } on ApiException catch (e) {
      throw Exception('경로 탐색에 실패했습니다. (${e.statusCode})');
    }

    switch (body['status'] as String?) {
      case 'ok':
        final route = body['route'];
        if (route is! Map<String, dynamic>) {
          throw Exception('경로 탐색에 실패했습니다.');
        }
        return SubwayRoute.fromJson(route);
      case 'not_found':
        return null;
      default:
        throw Exception('지금은 경로를 알아볼 수 없어요. 잠시 후 다시 시도해 주세요.');
    }
  }
}
