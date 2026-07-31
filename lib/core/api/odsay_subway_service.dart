import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

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
    final trafficType = json['trafficType'] as int;
    final lanes = json['lane'] as List<dynamic>?;
    return SubwayRouteStep(
      type: switch (trafficType) {
        1 => SubwayStepType.subway,
        2 => SubwayStepType.bus,
        _ => SubwayStepType.walk,
      },
      lineName: (lanes != null && lanes.isNotEmpty)
          ? (lanes.first as Map<String, dynamic>)['name'] as String?
          : null,
      startName: json['startName'] as String? ?? '',
      endName: json['endName'] as String? ?? '',
      sectionTimeMinutes: json['sectionTime'] as int? ?? 0,
      stationCount: json['stationCount'] as int?,
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
    final info = json['info'] as Map<String, dynamic>;
    final subPath = json['subPath'] as List<dynamic>? ?? const [];
    return SubwayRoute(
      totalTimeMinutes: info['totalTime'] as int? ?? 0,
      fare: info['payment'] as int? ?? 0,
      transferCount: info['subwayTransitCount'] as int? ?? 0,
      totalWalkMeters: info['totalWalk'] as int? ?? 0,
      steps: subPath
          .map((s) => SubwayRouteStep.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class OdsaySubwayService {
  OdsaySubwayService._();
  static final OdsaySubwayService instance = OdsaySubwayService._();

  static const _baseUrl = 'https://api.odsay.com/v1/api/searchPubTransPathT';

  /// [startLng]/[startLat]에서 [endLng]/[endLat]까지의 지하철 단독 경로 중
  /// 가장 빠른 경로를 반환한다. 지하철만으로 갈 수 없으면 null을 반환한다.
  Future<SubwayRoute?> findFastestSubwayRoute({
    required double startLng,
    required double startLat,
    required double endLng,
    required double endLat,
  }) async {
    // ODsay는 앱 등록 시 iOS/Android 번들 식별자별로 키를 따로 발급하므로
    // 실행 중인 OS에 맞는 키를 골라 써야 한다.
    final envKey = Platform.isIOS ? 'ODSAY_API_KEY_IOS' : 'ODSAY_API_KEY_ANDROID';
    final apiKey = dotenv.env[envKey] ?? '';
    if (apiKey.isEmpty) {
      throw Exception('$envKey가 설정되지 않았습니다.');
    }
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'SX': startLng.toString(),
      'SY': startLat.toString(),
      'EX': endLng.toString(),
      'EY': endLat.toString(),
      'apiKey': apiKey,
    });
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('경로 탐색에 실패했습니다. (${response.statusCode})');
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (body['error'] != null) {
      // ODsay는 에러를 단일 객체가 아니라 배열로 감싸서 내려준다: {"error": [{"message": "..."}]}
      final errors = body['error'] as List<dynamic>;
      final first = errors.isNotEmpty ? errors.first : null;
      final message = first is Map<String, dynamic>
          ? (first['message'] ?? first['msg'] ?? first.toString())
          : first?.toString();
      throw Exception(message ?? '경로 탐색에 실패했습니다.');
    }

    final result = body['result'] as Map<String, dynamic>?;
    final paths = result?['path'] as List<dynamic>? ?? const [];
    final subwayOnlyPaths = paths
        .cast<Map<String, dynamic>>()
        .where((p) => p['pathType'] == 1)
        .toList()
      ..sort((a, b) =>
          ((a['info'] as Map<String, dynamic>)['totalTime'] as int)
              .compareTo((b['info'] as Map<String, dynamic>)['totalTime'] as int));

    if (subwayOnlyPaths.isEmpty) return null;
    return SubwayRoute.fromJson(subwayOnlyPaths.first);
  }
}
