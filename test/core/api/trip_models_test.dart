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
    // 지어낸 장소에는 식별자가 없다. 그때 재탐색은 그 장소를 지목하지 못한다.
    expect(response.stops.first.contentId, isNull);
  });

  test('장소 식별자가 오면 그대로 읽는다', () {
    final response = TripGenerateResponse.fromJson({
      'trip_id': 'job-3',
      'total_duration_minutes': 0,
      'stops': [
        {...stopJson(), 'content_id': 'kakao:12345'},
      ],
      'weather_forecast': <dynamic>[],
    });

    expect(response.stops.first.contentId, 'kakao:12345');
  });

  test('재탐색 요청 본문이 서버와 맞춘 모양이다', () {
    final body = TripResearchRequest(
      startDate: DateTime(2026, 5, 1),
      endDate: DateTime(2026, 5, 2),
      activeStartHour: 9,
      activeEndHour: 20,
      minBudget: 50000,
      maxBudget: 150000,
      themes: const ['food'],
      transport: 'walk',
      province: '강원특별자치도',
      city: '속초시',
      prevTripId: 'job-1',
      exclude: const ['kakao:1'],
      keep: const [
        SelectedPlace(
          name: '속초해변',
          address: '강원특별자치도 속초시',
          latitude: 38.19,
          longitude: 128.60,
          day: 1,
          contentId: 'kakao:1',
        ),
      ],
      scheduleId: 42,
    ).toJson();

    expect(body['schedule'], {
      'start_date': '2026-05-01',
      'end_date': '2026-05-02',
      'active_start_hour': 9,
      'active_end_hour': 20,
    });
    expect(body['budget'], {'min': 50000, 'max': 150000});
    expect(body['prev_trip_id'], 'job-1');
    expect(body['exclude'], ['kakao:1']);
    expect((body['keep'] as List).single, containsPair('content_id', 'kakao:1'));
    expect(body['schedule_id'], 42);
  });

  test('비어 있는 제외·남길 목록은 키째 빠진다', () {
    final body = TripResearchRequest(
      startDate: DateTime(2026, 5, 1),
      endDate: DateTime(2026, 5, 1),
      activeStartHour: 9,
      activeEndHour: 20,
      minBudget: 0,
      maxBudget: 0,
      themes: const ['food'],
      transport: 'walk',
      province: '강원특별자치도',
      city: '속초시',
      prevTripId: 'job-1',
    ).toJson();

    expect(body.containsKey('exclude'), isFalse);
    expect(body.containsKey('keep'), isFalse);
    expect(body.containsKey('schedule_id'), isFalse);
  });

  test('제외 목록은 서버 상한까지만 싣는다', () {
    final body = TripResearchRequest(
      startDate: DateTime(2026, 5, 1),
      endDate: DateTime(2026, 5, 1),
      activeStartHour: 9,
      activeEndHour: 20,
      minBudget: 0,
      maxBudget: 0,
      themes: const ['food'],
      transport: 'walk',
      province: '강원특별자치도',
      city: '속초시',
      prevTripId: 'job-1',
      exclude: [for (int i = 0; i < 60; i++) 'kakao:$i'],
    ).toJson();

    expect(body['exclude'], hasLength(50));
  });
}
