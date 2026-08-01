import 'api_client.dart';

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

  const ScheduleSummary({
    required this.scheduleId,
    required this.title,
    required this.dateStart,
    required this.dateEnd,
  });

  factory ScheduleSummary.fromJson(Map<String, dynamic> json) =>
      ScheduleSummary(
        scheduleId: json['schedule_id'] as int,
        title: json['title'] as String? ?? '',
        dateStart: json['date_start'] is String
            ? DateTime.tryParse(json['date_start'] as String)
            : null,
        dateEnd: json['date_end'] is String
            ? DateTime.tryParse(json['date_end'] as String)
            : null,
      );
}
