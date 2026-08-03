import 'api_client.dart';
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

  const ScheduleSummary({
    required this.scheduleId,
    required this.title,
    required this.dateStart,
    required this.dateEnd,
    required this.createdAt,
  });

  factory ScheduleSummary.fromJson(Map<String, dynamic> json) =>
      ScheduleSummary(
        scheduleId: json['schedule_id'] as int,
        title: json['title'] as String? ?? '',
        dateStart: _date(json['date_start']),
        dateEnd: _date(json['date_end']),
        createdAt: _date(json['created_at']),
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

  const ScheduleDetail({
    required this.scheduleId,
    required this.title,
    required this.dateStart,
    required this.dateEnd,
    required this.transport,
    required this.totalDurationMinutes,
    required this.stops,
    required this.createdAt,
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
      );
}

DateTime? _date(dynamic v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;
