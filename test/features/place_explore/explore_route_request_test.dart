import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/api/trip_api_service.dart';
import 'package:map_service_client/core/state/trip_repository.dart';
import 'package:map_service_client/features/place_explore/utils/explore_route_request.dart';
import 'package:map_service_client/features/place_explore/utils/plan_place_id.dart';

/// 탐색에서 고른 장소를 동선 요청으로 접는 규칙 검증.
///
/// 요청 본문의 모양은 서버와 맞춘 계약이라 여기서 못으로 박아 둔다.
void main() {
  TripStop stop({
    required int order,
    required String name,
    int day = 1,
    double latitude = 38.19,
    double longitude = 128.60,
    String? category,
  }) =>
      TripStop(
        order: order,
        day: day,
        name: name,
        address: '$name 주소',
        time: '09:00',
        latitude: latitude,
        longitude: longitude,
        category: category,
      );

  TripPlanContext plan(List<TripStop> stops) => TripPlanContext(
        startDate: DateTime(2026, 5, 1),
        endDate: DateTime(2026, 5, 2),
        activeStartHour: 9,
        activeEndHour: 20,
        transport: 'walk',
        province: '강원특별자치도',
        city: '속초시',
        stops: stops,
      );

  final threeStops = [
    stop(order: 1, name: '속초해변', category: '여행 / 관광,명소 / 해수욕장,해변'),
    stop(order: 2, name: '영금정', latitude: 38.21),
    stop(order: 3, name: '속초 중앙시장', latitude: 38.20, category: '가정,생활 / 시장'),
  ];

  group('요청을 짤 수 있을 때', () {
    test('고른 순서와 무관하게 일정 순서로 담는다', () {
      final draft = buildExploreRouteDraft(
        plan: plan(threeStops),
        selectedIds: {planPlaceId(2), planPlaceId(0), planPlaceId(1)},
      );

      expect(draft.blockedBy, isNull);
      expect(draft.placeCount, 3);
      expect(
        draft.request!.places.map((p) => p.name),
        ['속초해변', '영금정', '속초 중앙시장'],
      );
    });

    test('분류를 함께 실어 보낸다', () {
      final draft = buildExploreRouteDraft(
        plan: plan(threeStops),
        selectedIds: {planPlaceId(0), planPlaceId(1), planPlaceId(2)},
      );

      final places = draft.request!.places;
      expect(places[0].category, '여행 / 관광,명소 / 해수욕장,해변');
      expect(places[1].category, isNull);
      expect(places[2].category, '가정,생활 / 시장');
    });

    test('일차는 원래 방문지에서 가져온다', () {
      final draft = buildExploreRouteDraft(
        plan: plan([
          stop(order: 1, name: '가', day: 1),
          stop(order: 2, name: '나', day: 2),
          stop(order: 3, name: '다', day: 2),
        ]),
        selectedIds: {planPlaceId(0), planPlaceId(1), planPlaceId(2)},
      );

      expect(draft.request!.places.map((p) => p.day), [1, 2, 2]);
    });

    test('보내는 본문이 서버와 맞춘 모양이다', () {
      final draft = buildExploreRouteDraft(
        plan: plan(threeStops),
        selectedIds: {planPlaceId(0), planPlaceId(1), planPlaceId(2)},
      );

      final json = draft.request!.toJson();
      expect(json.keys, containsAll(['schedule', 'transport', 'location', 'places']));
      expect(json['transport'], 'walk');
      expect((json['location'] as Map)['province'], '강원특별자치도');
      expect((json['location'] as Map)['city'], '속초시');
      final schedule = json['schedule'] as Map;
      expect(schedule['start_date'], '2026-05-01');
      expect(schedule['end_date'], '2026-05-02');
      expect(schedule['active_start_hour'], 9);
      expect(schedule['active_end_hour'], 20);

      final places = json['places'] as List;
      expect((places.first as Map).keys,
          containsAll(['name', 'address', 'lat', 'lng', 'day']));
      expect((places.first as Map)['category'], '여행 / 관광,명소 / 해수욕장,해변');
      // 분류를 모르는 장소는 키째 빠진다.
      expect((places[1] as Map).containsKey('category'), isFalse);
    });
  });

  group('요청을 짤 수 없을 때', () {
    test('손볼 일정이 없으면 막는다', () {
      final draft = buildExploreRouteDraft(plan: null, selectedIds: {planPlaceId(0)});

      expect(draft.blockedBy, ExploreRouteBlock.noPlan);
      expect(draft.request, isNull);
    });

    test('장소가 없는 일정도 없는 것으로 본다', () {
      final draft = buildExploreRouteDraft(plan: plan(const []), selectedIds: {});

      expect(draft.blockedBy, ExploreRouteBlock.noPlan);
    });

    test('고른 곳이 적으면 막는다', () {
      final draft = buildExploreRouteDraft(
        plan: plan(threeStops),
        selectedIds: {planPlaceId(0), planPlaceId(1)},
      );

      expect(draft.blockedBy, ExploreRouteBlock.tooFew);
      expect(draft.placeCount, 2);
      expect(draft.request, isNull);
    });

    test('고른 곳이 서버 상한을 넘으면 막는다', () {
      final many = [
        for (int i = 0; i < 11; i++) stop(order: i + 1, name: '장소$i'),
      ];
      final draft = buildExploreRouteDraft(
        plan: plan(many),
        selectedIds: {for (int i = 0; i < 11; i++) planPlaceId(i)},
      );

      expect(draft.blockedBy, ExploreRouteBlock.tooMany);
      expect(draft.placeCount, 11);
      expect(draft.request, isNull);
    });
  });

  test('알아볼 수 없는 선택은 빼고 센다', () {
    final draft = buildExploreRouteDraft(
      plan: plan(threeStops),
      selectedIds: {
        planPlaceId(0),
        planPlaceId(1),
        planPlaceId(2),
        planPlaceId(9), // 일정 밖
        'unknown', // 우리가 만든 모양이 아님
      },
    );

    expect(draft.blockedBy, isNull);
    expect(draft.placeCount, 3);
    expect(draft.request!.places, hasLength(3));
  });

  group('남길 장소만 두고 나머지를 새로 받을 때', () {
    TripStop identified({
      required int order,
      required String name,
      required String contentId,
    }) =>
        TripStop(
          order: order,
          name: name,
          address: '$name 주소',
          time: '09:00',
          latitude: 38.19,
          longitude: 128.60,
          contentId: contentId,
        );

    TripPlanContext researchablePlan(List<TripStop> stops) => TripPlanContext(
          startDate: DateTime(2026, 5, 1),
          endDate: DateTime(2026, 5, 2),
          activeStartHour: 9,
          activeEndHour: 20,
          transport: 'walk',
          province: '강원특별자치도',
          city: '속초시',
          stops: stops,
          tripId: 'job-1',
          minBudget: 50000,
          maxBudget: 150000,
          themes: const ['food'],
        );

    final identifiedStops = [
      identified(order: 1, name: '속초해변', contentId: 'kakao:1'),
      identified(order: 2, name: '영금정', contentId: 'kakao:2'),
      identified(order: 3, name: '중앙시장', contentId: 'kakao:3'),
    ];

    test('고른 곳은 남기고 지금 일정 전부를 제외 목록에 싣는다', () {
      final draft = buildExploreResearchDraft(
        plan: researchablePlan(identifiedStops),
        selectedIds: {planPlaceId(0)},
      );

      expect(draft.blockedBy, isNull);
      expect(draft.keepCount, 1);
      final body = draft.request!.toJson();
      expect(body['prev_trip_id'], 'job-1');
      expect((body['keep'] as List).single, containsPair('name', '속초해변'));
      expect((body['keep'] as List).single,
          containsPair('content_id', 'kakao:1'));
      // 남길 곳도 제외 목록에 함께 실린다 — 서버가 따로 세우므로 사라지지
      // 않고, 빠뜨리면 새로 뽑는 쪽에 같은 곳이 다시 나온다.
      expect(body['exclude'], ['kakao:1', 'kakao:2', 'kakao:3']);
    });

    test('하나도 고르지 않으면 전부 새로 받는다', () {
      final draft = buildExploreResearchDraft(
        plan: researchablePlan(identifiedStops),
        selectedIds: const {},
      );

      expect(draft.blockedBy, isNull);
      expect(draft.keepCount, 0);
      expect(draft.request!.toJson().containsKey('keep'), isFalse);
    });

    test('식별자 없는 장소는 남기지 못한다', () {
      final draft = buildExploreResearchDraft(
        plan: researchablePlan([
          identified(order: 1, name: '속초해변', contentId: 'kakao:1'),
          stop(order: 2, name: '지어낸 곳'),
        ]),
        selectedIds: {planPlaceId(0), planPlaceId(1)},
      );

      expect(draft.keepCount, 1);
      expect(draft.request!.keep.single.contentId, 'kakao:1');
      expect(draft.request!.exclude, ['kakao:1']);
    });

    test('조건이 없는 일정으로는 다시 물을 수 없다', () {
      final draft = buildExploreResearchDraft(
        plan: plan(identifiedStops),
        selectedIds: {planPlaceId(0)},
      );

      expect(draft.blockedBy, ExploreRouteBlock.noPlan);
      expect(draft.request, isNull);
    });

    test('남길 곳이 상한을 넘으면 막는다', () {
      final many = [
        for (int i = 0; i < 10; i++)
          identified(order: i + 1, name: '장소$i', contentId: 'kakao:$i'),
      ];
      final draft = buildExploreResearchDraft(
        plan: researchablePlan(many),
        selectedIds: {for (int i = 0; i < 10; i++) planPlaceId(i)},
      );

      expect(draft.blockedBy, ExploreRouteBlock.tooMany);
      expect(draft.request, isNull);
    });
  });
}
