import 'api_client.dart';

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

/// 사용자가 고른 장소 한 곳 — 동선만 다시 만들거나, 재탐색에서 그대로 둘
/// 장소를 지목할 때 서버로 보낸다.
///
/// 동선만 다시 만드는 경우 서버는 이름과 좌표로 장소를 다시 세운다. 재탐색에서
/// 남길 장소로 보낼 때는 [contentId] 가 있어야 한다 — 그 값이 있어야 서버가
/// 다시 뽑는 장소와 남길 장소를 맞대 볼 수 있고, 없으면 같은 곳이 두 번 들어갈
/// 수 있다.
class SelectedPlace {
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final int day;

  /// 장소 분류. 고른 장소로 동선만 다시 만들 때, 서버는 이 장소를 새로
  /// 찾아보지 않아 분류를 알 방법이 없다. 처음 받았던 값을 그대로 실어
  /// 보내야 결과 화면의 분류 칩이 남는다. 모르면 싣지 않는다.
  final String? category;

  /// 추천을 가로질러 같은 장소를 가리키는 식별자("kakao:123").
  /// 서버가 지어낸 장소에는 없다.
  final String? contentId;

  const SelectedPlace({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.day,
    this.category,
    this.contentId,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'lat': latitude,
        'lng': longitude,
        'day': day,
        if (category != null && category!.isNotEmpty) 'category': category,
        if (contentId != null && contentId!.isNotEmpty) 'content_id': contentId,
      };
}

/// 고른 장소로 동선만 다시 만드는 요청.
///
/// 예산·테마를 담지 않는다. 후보를 고를 때 쓰는 조건인데 장소가 이미
/// 정해져 있어 쓸 곳이 없다.
class TripRouteRequest {
  final DateTime startDate;
  final DateTime endDate;
  final int activeStartHour;
  final int activeEndHour;
  final String transport;
  final String province;
  final String city;
  final List<SelectedPlace> places;

  const TripRouteRequest({
    required this.startDate,
    required this.endDate,
    required this.activeStartHour,
    required this.activeEndHour,
    required this.transport,
    required this.province,
    required this.city,
    required this.places,
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
        'transport': transport,
        'location': {
          'province': province,
          'city': city,
        },
        'places': places.map((p) => p.toJson()).toList(),
      };
}

/// 같은 조건에서 다른 장소로 다시 추천받는 요청.
///
/// 조건은 방금 받은 추천에 썼던 것을 그대로 다시 싣는다 — 조건을 바꾸는 것이
/// 아니라 같은 조건에서 다른 결과를 받는 흐름이라, 사용자에게 입력을 다시
/// 받지 않는다.
///
/// [keep] 이 비어 있으면 전부 다시 뽑고, 채워 보내면 그 장소는 남고 나머지
/// 자리만 새로 채워진다. [exclude] 에는 방금 본 장소를 전부 싣는다 — 남길
/// 장소까지 포함해서다. 서버가 남길 장소는 따로 세우므로 겹쳐도 사라지지
/// 않으며, 빠뜨리면 그 장소가 새로 뽑히는 쪽에 다시 나올 수 있다.
class TripResearchRequest {
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

  /// 방금 받은 추천의 식별자(trip_id).
  final String prevTripId;

  /// 다시 나오면 안 되는 장소들의 식별자.
  final List<String> exclude;

  /// 그대로 둘 장소들. 비어 있으면 전부 다시 뽑는다.
  final List<SelectedPlace> keep;

  /// 저장된 일정을 재탐색하는 경우의 일정 식별자.
  final int? scheduleId;

  const TripResearchRequest({
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
    required this.prevTripId,
    this.exclude = const [],
    this.keep = const [],
    this.scheduleId,
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
        'prev_trip_id': prevTripId,
        // 서버 계약 상한이 50개다. 넘겨 보내면 요청 자체가 거절되므로 여기서
        // 자른다 — 잘린 장소가 다시 나올 수는 있어도 재탐색은 성립한다.
        if (exclude.isNotEmpty) 'exclude': exclude.take(50).toList(),
        if (keep.isNotEmpty) 'keep': keep.map((p) => p.toJson()).toList(),
        if (scheduleId != null) 'schedule_id': scheduleId,
      };
}

// ─── Response ─────────────────────────────────────────────────

class TripTransportToNext {
  /// 이동수단 코드. 일정을 저장할 때 이동수단을 함께 남기기 전에 만들어진
  /// 일정에는 이 값이 없다. 화면은 이동수단을 label 로 판별하므로 없어도
  /// 카드는 그대로 그려진다.
  final String? type;
  final String label;
  final int durationMinutes;
  final double distanceKm;

  /// 다음 stop 까지의 도로 추종 폴리라인 [[lat, lng], ...].
  /// 경로 조회가 성공한 구간에만 채워지며(없으면 null), 없을 때 지도는 직선 폴백.
  final List<List<double>>? path;

  const TripTransportToNext({
    this.type,
    required this.label,
    required this.durationMinutes,
    required this.distanceKm,
    this.path,
  });

  /// 값이 빠져 있어도 카드를 만든다.
  ///
  /// 예전에 저장된 일정에는 이동수단이 없어 서버가 그 자리를 비워 보낸다.
  /// 여기서 형을 단정해 읽으면 그런 일정은 화면 전체가 예외로 죽는데,
  /// 이동 카드 하나 때문에 일정을 못 여는 것은 과한 대가다.
  factory TripTransportToNext.fromJson(Map<String, dynamic> json) =>
      TripTransportToNext(
        type: json['type'] as String?,
        label: json['label'] as String? ?? '이동',
        durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
        distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
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

  /// 장소 분류(예: 해변, 카페). 상세 시트의 분류 칩에 쓴다.
  final String? category;

  /// 블로그 후기를 종합한 요약 두 줄. 근거가 될 후기를 못 구한 장소는
  /// 아예 오지 않으므로 카드에서 이 영역을 통째로 접어야 한다.
  final List<String>? bullets;

  /// 이 장소를 떠나는 예정 시각(HH:mm). 타임라인 이전에 만든 일정에는 없다.
  final String? endTime;

  /// 이 장소에 머무는 예정 시간(분). endTime 과 같은 조건에서만 온다.
  final int? stayMinutes;

  /// 추천을 가로질러 같은 장소를 가리키는 식별자("kakao:123"). 재탐색에서
  /// "이 장소 말고" 또는 "이 장소는 그대로"라고 지목하는 키다. 서버가
  /// 지어낸 장소에는 없다.
  final String? contentId;

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
    this.category,
    this.bullets,
    this.endTime,
    this.stayMinutes,
    this.contentId,
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
        // 아래 값들은 서버가 못 채우면 키 자체가 없다. 필수 필드처럼
        // 캐스팅하면 요약이 없는 장소 하나 때문에 화면 전체가 죽으므로,
        // 타입이 어긋나는 값은 조용히 버리고 없는 것으로 취급한다.
        placeId: json['place_id'] is int ? json['place_id'] as int : null,
        placeUrl: json['place_url'] is String ? json['place_url'] as String : null,
        reason: json['reason'] is String ? json['reason'] as String : null,
        category: json['category'] is String ? json['category'] as String : null,
        bullets: (json['bullets'] as List<dynamic>?)
            ?.whereType<String>()
            .where((line) => line.trim().isNotEmpty)
            .take(2)
            .toList(),
        endTime: json['end_time'] is String ? json['end_time'] as String : null,
        stayMinutes:
            json['stay_minutes'] is num ? (json['stay_minutes'] as num).toInt() : null,
        contentId: json['content_id'] is String ? json['content_id'] as String : null,
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

  /// 추천 과정에서 반영하지 못한 조건 안내(예: 날씨 미확인). 사용자에게
  /// 그대로 보여줄 문장 목록이며, 없으면 키 자체가 오지 않는다.
  final List<String> warnings;

  const TripGenerateResponse({
    required this.tripId,
    required this.totalDurationMinutes,
    required this.stops,
    required this.weatherForecast,
    this.warnings = const [],
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
        warnings: (json['warnings'] as List<dynamic>?)
                ?.whereType<String>()
                .where((line) => line.trim().isNotEmpty)
                .toList() ??
            const [],
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

  // 여행 생성은 LLM 여러 번 호출로 수 초~2분 소요된다. 무한 대기를 막되,
  // 서버가 먼저 끊고 사유를 담은 응답을 줄 수 있도록 서버 대기 상한보다
  // 길게 잡는다(서버 150초). 이 값이 서버보다 짧으면 서버가 아직 살아 있는
  // 요청을 클라이언트가 먼저 버려, 곧 도착할 결과를 못 받고 실패로 표시한다.
  static const _requestTimeout = Duration(seconds: 180);

  Future<TripGenerateResponse> generateTrip(TripGenerateRequest request) =>
      _postTrip('/api/v1/trip/generate', request.toJson());

  /// 고른 장소로 동선만 다시 만든다.
  ///
  /// 응답 형태가 일정 생성과 같아서 결과 화면을 그대로 재사용한다.
  Future<TripGenerateResponse> routeTrip(TripRouteRequest request) =>
      _postTrip('/api/v1/trip/route', request.toJson());

  /// 같은 조건으로 다른 장소를 다시 추천받는다.
  ///
  /// 하루 횟수 한도가 있어 넘기면 409 가 온다 — 화면은 그 사유를 그대로
  /// 보여 주고 되돌아간다.
  Future<TripGenerateResponse> researchTrip(TripResearchRequest request) =>
      _postTrip('/api/v1/trip/research', request.toJson());

  /// 일정 응답을 돌려주는 두 경로가 공유하는 전송부.
  ///
  /// 오류 본문 형태가 서버 계층마다 달라, 알아볼 수 있는 키를 순서대로
  /// 찾아본다. 어느 것도 없으면 상태 코드만 남긴다.
  Future<TripGenerateResponse> _postTrip(
    String path,
    Map<String, dynamic> body,
  ) async {
    // 공통 통로로 보낸다. 직접 보내면 토큰이 실리지 않고 만료 갱신도 없어,
    // 서버에서 인증을 켜는 순간 일정 생성과 동선 재생성이 함께 막힌다.
    // 앱에서 가장 오래 걸리는 요청이라 기다리는 시간은 여기서 따로 준다.
    try {
      final parsed = await ApiClient.instance
          .post(path, body: body, timeout: _requestTimeout);
      return TripGenerateResponse.fromJson(parsed);
    } on ApiException catch (e) {
      // 공통 통로가 이미 오류 본문의 키를 순서대로 훑어 접어 준다. 여기서는
      // 화면이 기다리는 예외 형태로만 바꾼다.
      throw TripApiException(
        error: e.statusCode == 408 ? 'REQUEST_TIMEOUT' : e.code,
        message: e.statusCode == 408
            ? '여행 생성이 지연되고 있어요. 잠시 후 다시 시도해주세요.'
            : e.message,
        statusCode: e.statusCode,
      );
    } on FormatException {
      // 본문이 비었거나 JSON 이 아닌 응답(게이트웨이 오류 등).
      throw TripApiException(
        error: 'INVALID_RESPONSE',
        message: '서버 응답을 읽지 못했어요. 잠시 후 다시 시도해주세요.',
        statusCode: 502,
      );
    }
  }
}
