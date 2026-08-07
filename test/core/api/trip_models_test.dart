import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/api/trip_api_service.dart';

/// 생성 응답의 warnings 와 방문지 타임라인 필드 해석 검증.
///
/// warnings/end_time/stay_minutes 는 서버가 못 채우면 키 자체가 없다.
/// 없는 응답(과거 형식)과 있는 응답 둘 다 그대로 열려야 한다.
void main() {
  Map<String, dynamic> stopJson({bool withTimeline = false}) => {
        'order': 1,
        'day': 1,
        'name': '속초해변',
        'address': '강원특별자치도 속초시',
        'time': '09:00',
        'latitude': 38.19,
        'longitude': 128.60,
        if (withTimeline) 'end_time': '10:30',
        if (withTimeline) 'stay_minutes': 90,
      };

  test('warnings 와 타임라인 필드가 있으면 그대로 싣는다', () {
    final response = TripGenerateResponse.fromJson({
      'trip_id': 'job-1',
      'total_duration_minutes': 30,
      'stops': [stopJson(withTimeline: true)],
      'weather_forecast': <dynamic>[],
      'warnings': ['날씨 정보를 확인하지 못해 일정에 반영하지 못했습니다'],
    });

    expect(response.warnings, hasLength(1));
    expect(response.warnings.first, contains('날씨'));
    expect(response.stops.first.endTime, '10:30');
    expect(response.stops.first.stayMinutes, 90);
  });

  test('키가 없는 과거 형식 응답도 그대로 열린다', () {
    final response = TripGenerateResponse.fromJson({
      'trip_id': 'job-2',
      'total_duration_minutes': 0,
      'stops': [stopJson()],
      'weather_forecast': <dynamic>[],
    });

    expect(response.warnings, isEmpty);
    expect(response.stops.first.endTime, isNull);
    expect(response.stops.first.stayMinutes, isNull);
  });
}
