import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ─── Request ──────────────────────────────────────────────────

class TripGenerateRequest {
  final DateTime startDate;
  final DateTime endDate;
  final int activeStartHour;
  final int activeEndHour;
  final int minBudget;
  final int maxBudget;
  final List<String> themes;
  final String transport;
  final String province;
  final String city;

  const TripGenerateRequest({
    required this.startDate,
    required this.endDate,
    required this.activeStartHour,
    required this.activeEndHour,
    required this.minBudget,
    required this.maxBudget,
    required this.themes,
    required this.transport,
    required this.province,
    required this.city,
  });

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'schedule': {
          'start_date': _fmtDate(startDate),
          'end_date': _fmtDate(endDate),
          'active_start_hour': activeStartHour,
          'active_end_hour': activeEndHour,
        },
        'budget': {
          'min': minBudget,
          'max': maxBudget,
        },
        'themes': themes,
        'transport': transport,
        'location': {
          'province': province,
          'city': city,
        },
      };
}

// ─── Response ─────────────────────────────────────────────────

class TripTransportToNext {
  final String type;
  final String label;
  final int durationMinutes;
  final double distanceKm;

  /// 다음 stop 까지의 도로 추종 폴리라인 [[lat, lng], ...].
  /// 경로 조회가 성공한 구간에만 채워지며(없으면 null), 없을 때 지도는 직선 폴백.
  final List<List<double>>? path;

  const TripTransportToNext({
    required this.type,
    required this.label,
    required this.durationMinutes,
    required this.distanceKm,
    this.path,
  });

  factory TripTransportToNext.fromJson(Map<String, dynamic> json) =>
      TripTransportToNext(
        type: json['type'] as String,
        label: json['label'] as String,
        durationMinutes: json['duration_minutes'] as int,
        distanceKm: (json['distance_km'] as num).toDouble(),
        path: (json['path'] as List<dynamic>?)
            ?.map((p) => (p as List<dynamic>)
                .map((v) => (v as num).toDouble())
                .toList())
            .toList(),
      );
}

class TripStop {
  final int order;
  final int day; // 1부터 시작하는 여행 일차
  final String name;
  final String address;
  final String time; // HH:mm
  final double latitude;
  final double longitude;
  final TripTransportToNext? transportToNext;

  /// 서버가 부여한 장소 식별자. 장소 상세를 다시 물어보거나, 고른 장소로
  /// 동선을 다시 요청할 때 이 장소를 지목하는 키다.
  final int? placeId;

  /// 출처 서비스의 장소 페이지 링크.
  final String? placeUrl;

  /// 이 장소를 추천한 이유 한 문장.
  final String? reason;

  /// 블로그 후기를 종합한 요약 두 줄. 근거가 될 후기를 못 구한 장소는
  /// 아예 오지 않으므로 카드에서 이 영역을 통째로 접어야 한다.
  final List<String>? bullets;

  const TripStop({
    required this.order,
    this.day = 1,
    required this.name,
    required this.address,
    required this.time,
    required this.latitude,
    required this.longitude,
    this.transportToNext,
    this.placeId,
    this.placeUrl,
    this.reason,
    this.bullets,
  });

  factory TripStop.fromJson(Map<String, dynamic> json) => TripStop(
        order: json['order'] as int,
        day: json['day'] as int? ?? 1,
        name: json['name'] as String,
        address: json['address'] as String,
        time: json['time'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        transportToNext: json['transport_to_next'] != null
            ? TripTransportToNext.fromJson(
                json['transport_to_next'] as Map<String, dynamic>)
            : null,
        // 아래 네 값은 서버가 못 채우면 키 자체가 없다. 필수 필드처럼
        // 캐스팅하면 요약이 없는 장소 하나 때문에 화면 전체가 죽으므로,
        // 타입이 어긋나는 값은 조용히 버리고 없는 것으로 취급한다.
        placeId: json['place_id'] is int ? json['place_id'] as int : null,
        placeUrl: json['place_url'] is String ? json['place_url'] as String : null,
        reason: json['reason'] is String ? json['reason'] as String : null,
        bullets: (json['bullets'] as List<dynamic>?)
            ?.whereType<String>()
            .where((line) => line.trim().isNotEmpty)
            .take(2)
            .toList(),
      );
}

class WeatherForecast {
  final String date;
  final String condition; // sunny | cloudy | rainy | snowy
  final int tempHigh;
  final int tempLow;
  final int precipitationProbability;

  const WeatherForecast({
    required this.date,
    required this.condition,
    required this.tempHigh,
    required this.tempLow,
    required this.precipitationProbability,
  });

  factory WeatherForecast.fromJson(Map<String, dynamic> json) => WeatherForecast(
        date: json['date'] as String,
        condition: json['condition'] as String,
        tempHigh: json['temp_high'] as int,
        tempLow: json['temp_low'] as int,
        precipitationProbability: json['precipitation_probability'] as int,
      );
}

class TripGenerateResponse {
  final String tripId;
  final int totalDurationMinutes;
  final List<TripStop> stops;
  final List<WeatherForecast> weatherForecast;

  const TripGenerateResponse({
    required this.tripId,
    required this.totalDurationMinutes,
    required this.stops,
    required this.weatherForecast,
  });

  factory TripGenerateResponse.fromJson(Map<String, dynamic> json) =>
      TripGenerateResponse(
        tripId: json['trip_id'] as String,
        totalDurationMinutes: json['total_duration_minutes'] as int,
        stops: (json['stops'] as List<dynamic>)
            .map((s) => TripStop.fromJson(s as Map<String, dynamic>))
            .toList(),
        weatherForecast: (json['weather_forecast'] as List<dynamic>)
            .map((w) => WeatherForecast.fromJson(w as Map<String, dynamic>))
            .toList(),
      );
}

// ─── Exceptions ───────────────────────────────────────────────

class TripApiException implements Exception {
  final String error;
  final String message;
  final int statusCode;

  const TripApiException({
    required this.error,
    required this.message,
    required this.statusCode,
  });

  @override
  String toString() => '[$statusCode] $error: $message';
}

// ─── Service ─────────────────────────────────────────────────

class TripApiService {
  TripApiService._();
  static final TripApiService instance = TripApiService._();

  static const _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  // 여행 생성은 LLM 여러 번 호출로 수 초~2분 소요된다. 무한 대기를 막되,
  // 서버가 먼저 끊고 사유를 담은 응답을 줄 수 있도록 서버 대기 상한보다
  // 길게 잡는다(서버 150초). 이 값이 서버보다 짧으면 서버가 아직 살아 있는
  // 요청을 클라이언트가 먼저 버려, 곧 도착할 결과를 못 받고 실패로 표시한다.
  static const _requestTimeout = Duration(seconds: 180);

  Future<TripGenerateResponse> generateTrip(TripGenerateRequest request) async {
    final uri = Uri.parse('$_baseUrl/api/v1/trip/generate');
    final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(request.toJson()),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw TripApiException(
        error: 'REQUEST_TIMEOUT',
        message: '여행 생성이 지연되고 있어요. 잠시 후 다시 시도해주세요.',
        statusCode: 408,
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return TripGenerateResponse.fromJson(body);
    }

    throw TripApiException(
      error: body['error'] as String? ?? 'UNKNOWN_ERROR',
      message: body['message'] as String? ?? '알 수 없는 오류가 발생했습니다.',
      statusCode: response.statusCode,
    );
  }
}
