import 'api_client.dart';
import '../../data/models/weather_alert.dart';
import 'trip_api_service.dart';

/// 일정 저장·조회·삭제.
///
/// 저장은 토큰 없이도 서버가 받아 주지만, 그렇게 저장한 일정은 **주인이
/// 없어** 다시 꺼내 볼 수도 채팅방을 만들 수도 없다. 그래서 이 서비스를
/// 거치는 모든 호출에 토큰을 싣는다(공통 계층이 자동으로 붙인다).
class ScheduleApiService {
  ScheduleApiService._();
  static final ScheduleApiService instance = ScheduleApiService._();

  final _api = ApiClient.instance;

  /// 방금 만든 일정을 저장한다.
  ///
  /// jobId: 일정 생성 응답의 식별자. 서버가 이 값으로 원본을 찾아 담는다.
  /// transport·활동 시간대는 다시 열 때 같은 화면을 만들기 위해 함께 보낸다 —
  /// 추천 결과 원본에는 이 값들이 없다.
  ///
  /// 반환: 저장된 일정의 식별자. 채팅방을 만들 때 이 값으로 일정을 지목한다.
  Future<int> save({
    required String jobId,
    required String title,
    required DateTime dateStart,
    required DateTime dateEnd,
    required String transport,
    required int activeStartHour,
    required int activeEndHour,
  }) async {
    final json = await _api.post('/api/v1/schedules', body: {
      'job_id': jobId,
      'title': title,
      'date_start': _fmtDate(dateStart),
      'date_end': _fmtDate(dateEnd),
      'transport': transport,
      'active_start_hour': activeStartHour,
      'active_end_hour': activeEndHour,
    });
    return json['schedule_id'] as int;
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';

  /// 내가 저장한 일정 목록. 토큰이 없으면 서버가 빈 목록을 준다.
  Future<List<ScheduleSummary>> list() async {
    final json = await _api.get('/api/v1/schedules');
    final items = json['schedules'];
    if (items is! List) return const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(ScheduleSummary.fromJson)
        .toList();
  }

  /// 저장된 일정 하나를 방문지까지 조립해 받는다.
  ///
  /// 목록에는 제목과 기간만 있다 — 방문지·이동 카드·도로 경로는 여기서만 온다.
  /// 서버가 조회 시점 기준으로 경로를 다시 얹으므로 오래전 일정도 지금 경로로 열린다.
  Future<ScheduleDetail> detail(int scheduleId) async {
    final json = await _api.get('/api/v1/schedules/$scheduleId');
    return ScheduleDetail.fromJson(json);
  }

  /// 이 일정을 따라가기 시작했다고 알리고 상세를 받는다.
  ///
  /// 시작 시각은 서버가 처음 한 번만 새기므로 몇 번을 불러도 결과가 같다.
  /// 상세를 함께 받는 이유는 시작 화면이 쓸 방문지·이동 카드·도로 경로가
  /// 상세에서만 오기 때문이다 — 따로 부르면 왕복이 두 번이 된다.
  Future<ScheduleDetail> start(int scheduleId) async {
    final json = await _api.post('/api/v1/schedules/$scheduleId/start');
    return ScheduleDetail.fromJson(json);
  }

  /// 날씨 알림을 받아들이지 않고 지운다("이대로 갈게요").
  ///
  /// 서버가 알림을 지우면서 기준선을 지금 예보로 옮기므로, 같은 변화가 다시
  /// 알림으로 뜨지 않는다. 이후 예보가 또 달라지면 그때 다시 알린다.
  Future<void> dismissWeatherAlert(int scheduleId) async {
    await _api.post('/api/v1/schedules/$scheduleId/weather-alert/dismiss');
  }

  Future<void> delete(int scheduleId) async {
    await _api.delete('/api/v1/schedules/$scheduleId');
  }
}

/// 저장 목록에 실리는 일정 한 건.
class ScheduleSummary {
  final int scheduleId;
  final String title;
  final DateTime? dateStart;
  final DateTime? dateEnd;

  /// 저장 시각. 목록의 등록순 정렬 근거.
  /// 여행 기간과 다르다 — 다음 달 여행을 오늘 저장하면 등록은 오늘이다.
  final DateTime? createdAt;

  /// 걸려 있는 날씨 변화 알림. 없으면 null(응답에 필드가 아예 없다).
  final WeatherAlert? weatherAlert;

  const ScheduleSummary({
    required this.scheduleId,
    required this.title,
    required this.dateStart,
    required this.dateEnd,
    required this.createdAt,
    this.weatherAlert,
  });

  factory ScheduleSummary.fromJson(Map<String, dynamic> json) =>
      ScheduleSummary(
        scheduleId: json['schedule_id'] as int,
        title: json['title'] as String? ?? '',
        dateStart: _date(json['date_start']),
        dateEnd: _date(json['date_end']),
        createdAt: _date(json['created_at']),
        weatherAlert: WeatherAlert.fromJson(
            json['weather_alert'] as Map<String, dynamic>?),
      );
}

/// 저장된 일정 상세.
/// stops 는 일정 생성 응답과 같은 형식이라 결과 화면을 그대로 재사용한다.
class ScheduleDetail {
  final int scheduleId;
  final String title;
  final DateTime? dateStart;
  final DateTime? dateEnd;
  final String? transport;
  final int totalDurationMinutes;
  final List<TripStop> stops;
  final DateTime? createdAt;

  /// 이 일정을 처음 따라가기 시작한 시각. 시작한 적이 없으면 null.
  final DateTime? startedAt;

  /// 걸려 있는 날씨 변화 알림. 없으면 null.
  final WeatherAlert? weatherAlert;

  /// 추천 당시 반영하지 못한 조건 안내. 생성 화면과 같은 안내를 저장 후
  /// 재열람에서도 보여준다. 없으면 빈 목록.
  final List<String> warnings;

  const ScheduleDetail({
    required this.scheduleId,
    required this.title,
    required this.dateStart,
    required this.dateEnd,
    required this.transport,
    required this.totalDurationMinutes,
    required this.stops,
    required this.createdAt,
    this.startedAt,
    this.warnings = const [],
    this.weatherAlert,
  });

  factory ScheduleDetail.fromJson(Map<String, dynamic> json) => ScheduleDetail(
        scheduleId: json['schedule_id'] as int,
        title: json['title'] as String? ?? '',
        dateStart: _date(json['date_start']),
        dateEnd: _date(json['date_end']),
        transport: json['transport'] as String?,
        totalDurationMinutes: json['total_duration_minutes'] as int? ?? 0,
        stops: (json['stops'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(TripStop.fromJson)
            .toList(),
        createdAt: _date(json['created_at']),
        startedAt: _date(json['started_at']),
        warnings: (json['warnings'] as List<dynamic>?)
                ?.whereType<String>()
                .where((line) => line.trim().isNotEmpty)
                .toList() ??
            const [],
        weatherAlert: WeatherAlert.fromJson(
            json['weather_alert'] as Map<String, dynamic>?),
      );
}

DateTime? _date(dynamic v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;
