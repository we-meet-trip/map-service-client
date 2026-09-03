import 'api_client.dart';

// 지하철 경로 조회
//
// 발급처를 앱이 직접 부르지 않는다. 그러면 인증키가 앱 꾸러미에 함께 실려
// 나가고, 운영체제별로 키를 따로 들고 다녀야 한다. 서버가 대신 물어 오면
// 키는 서버에만 남고 앱은 https 로만 말한다.

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
    required this.lineName,
    required this.startName,
    required this.endName,
    required this.sectionTimeMinutes,
    required this.stationCount,
  });

  factory SubwayRouteStep.fromServer(Map<String, dynamic> json) {
    return SubwayRouteStep(
      type: switch (json['type']) {
        'subway' => SubwayStepType.subway,
        'bus' => SubwayStepType.bus,
        _ => SubwayStepType.walk,
      },
      lineName: json['line_name'] as String?,
      startName: (json['start_name'] as String?) ?? '',
      endName: (json['end_name'] as String?) ?? '',
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

  factory SubwayRoute.fromServer(Map<String, dynamic> json) {
    final steps = json['steps'];
    return SubwayRoute(
      totalTimeMinutes: (json['total_time_min'] as num?)?.toInt() ?? 0,
      fare: (json['fare'] as num?)?.toInt() ?? 0,
      transferCount: (json['transfer_count'] as num?)?.toInt() ?? 0,
      totalWalkMeters: (json['total_walk_m'] as num?)?.toInt() ?? 0,
      steps: steps is List
          ? steps
              .whereType<Map<String, dynamic>>()
              .map(SubwayRouteStep.fromServer)
              .toList()
          : const [],
    );
  }
}

// 길이 없는 것과 물어보지 못한 것은 다른 일이다. 둘을 한 값으로 합치면 바깥
// 장애가 "갈 수 있는 길이 없다"로 보여서 사용자가 잘못된 결론을 얻는다.
// 그래서 서버가 나눠 보내 주는 구분을 화면까지 그대로 들고 간다.
enum SubwayRouteStatus { ok, notFound, unavailable }

class SubwayRouteResult {
  final SubwayRouteStatus status;
  final SubwayRoute? route;

  const SubwayRouteResult(this.status, this.route);
}

class SubwayRouteService {
  SubwayRouteService._();

  static final SubwayRouteService instance = SubwayRouteService._();

  Future<SubwayRouteResult> findFastestSubwayRoute({
    required double startLng,
    required double startLat,
    required double endLng,
    required double endLat,
  }) async {
    final body = await ApiClient.instance.get(
      '/api/v1/transit/subway',
      query: {
        'startLat': '$startLat',
        'startLng': '$startLng',
        'endLat': '$endLat',
        'endLng': '$endLng',
      },
    );
    return parseSubwayRouteResponse(body);
  }
}

// 응답 해석만 따로 둔다. 통신 없이 그대로 시험할 수 있게 하려는 것이다.
SubwayRouteResult parseSubwayRouteResponse(Map<String, dynamic> body) {
  final route = body['route'];
  return switch (body['status']) {
    'ok' when route is Map<String, dynamic> => SubwayRouteResult(
        SubwayRouteStatus.ok,
        SubwayRoute.fromServer(route),
      ),
    'not_found' => const SubwayRouteResult(SubwayRouteStatus.notFound, null),
    _ => const SubwayRouteResult(SubwayRouteStatus.unavailable, null),
  };
}
