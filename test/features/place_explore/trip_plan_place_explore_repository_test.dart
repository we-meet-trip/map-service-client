import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/api/trip_api_service.dart';
import 'package:map_service_client/core/state/trip_repository.dart';
import 'package:map_service_client/features/place_explore/data/trip_plan_place_explore_repository.dart';

/// 탐색 지도가 방금 만든 일정의 장소를 그대로 쓰는지 검증.
///
/// 마커 식별자는 웹 지도가 배지 번호를 뽑아내는 근거라 0부터 세는 순번이
/// 붙어야 하고, 분류가 없는 장소도 빠짐없이 실려야 한다.
void main() {
  TripStop stop({
    required int order,
    required String name,
    String address = '강원특별자치도 속초시',
    double latitude = 38.19,
    double longitude = 128.60,
    String? category,
  }) =>
      TripStop(
        order: order,
        name: name,
        address: address,
        time: '09:00',
        latitude: latitude,
        longitude: longitude,
        category: category,
      );

  void givenPlan(List<TripStop> stops) {
    TripRepository.instance.setLastPlan(
      TripPlanContext(
        startDate: DateTime(2026, 5, 1),
        endDate: DateTime(2026, 5, 1),
        activeStartHour: 9,
        activeEndHour: 20,
        transport: 'walk',
        province: '강원특별자치도',
        city: '속초시',
        stops: stops,
      ),
    );
  }

  setUp(() => TripRepository.instance.lastPlan = null);
  tearDown(() => TripRepository.instance.lastPlan = null);

  final repository = TripPlanPlaceExploreRepository();

  test('일정의 장소를 순번 식별자와 함께 싣는다', () async {
    givenPlan([
      stop(order: 1, name: '속초해변', category: '여행 / 관광,명소 / 해수욕장,해변'),
      stop(order: 2, name: '속초 중앙시장', latitude: 38.20, longitude: 128.59),
    ]);

    final places = await repository.getPlaces();

    expect(places, hasLength(2));
    expect(places[0].id, 'stop_0');
    expect(places[0].name, '속초해변');
    expect(places[0].address, '강원특별자치도 속초시');
    expect(places[0].category, '여행 / 관광,명소 / 해수욕장,해변');
    expect(places[0].latitude, 38.19);
    expect(places[1].id, 'stop_1');
    expect(places[1].longitude, 128.59);
  });

  test('분류가 없는 장소도 그대로 싣는다', () async {
    givenPlan([stop(order: 1, name: '속초 버스 터미널')]);

    final places = await repository.getPlaces();

    expect(places.single.category, isNull);
  });

  test('같은 장소가 여러 날에 있으면 각각 마커가 된다', () async {
    givenPlan([
      stop(order: 1, name: '속초해변'),
      stop(order: 2, name: '속초해변'),
    ]);

    final places = await repository.getPlaces();

    expect(places.map((p) => p.id), ['stop_0', 'stop_1']);
  });

  test('상세는 지도가 이미 아는 값만 채우고 후기 자리는 비워 둔다', () async {
    givenPlan([
      stop(order: 1, name: '속초해변'),
      stop(order: 2, name: '영금정', address: '강원특별자치도 속초시 동명동', category: '관광명소'),
    ]);

    final detail = await repository.getPlaceDetail('stop_1');

    expect(detail.id, 'stop_1');
    expect(detail.name, '영금정');
    expect(detail.address, '강원특별자치도 속초시 동명동');
    expect(detail.category, '관광명소');
    expect(detail.aiSummary, isEmpty);
    expect(detail.blogReviews, isEmpty);
  });

  test('일정에 없는 식별자는 상세를 만들지 않는다', () async {
    givenPlan([stop(order: 1, name: '속초해변')]);

    expect(repository.getPlaceDetail('stop_9'), throwsStateError);
    expect(repository.getPlaceDetail('unknown'), throwsStateError);
  });

  test('일정이 없으면 장소를 내주지 않는다', () async {
    expect(repository.getPlaces(), throwsStateError);
    expect(repository.getPlaceDetail('stop_0'), throwsStateError);
  });

  test('장소가 빈 일정도 없는 것으로 본다', () async {
    givenPlan(const []);

    expect(repository.getPlaces(), throwsStateError);
  });
}
