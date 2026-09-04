import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/api/trip_api_service.dart';
import 'package:map_service_client/features/trip/utils/manual_route_request.dart';

/// 직접 고친 일정을 동선 요청으로 접는 규칙 검증.
///
/// 화면에 보이는 순서와 일차, 그리고 장소를 되살릴 값(분류·식별자)이 그대로
/// 실려야 한다 — 서버는 이 요청에서 장소를 새로 찾지 않는다.
void main() {
  TripStop stop({
    required int order,
    required String name,
    int day = 1,
    String? category,
    String? contentId,
  }) =>
      TripStop(
        order: order,
        day: day,
        name: name,
        address: '$name 주소',
        time: '',
        latitude: 38.19,
        longitude: 128.60,
        category: category,
        contentId: contentId,
      );

  ManualRouteDraft draftOf(List<TripStop> stops) => buildManualRouteDraft(
        stops: stops,
        startDate: DateTime(2026, 5, 1),
        endDate: DateTime(2026, 5, 2),
        activeStartHour: 9,
        activeEndHour: 20,
        transport: 'walk',
        province: '강원특별자치도',
        city: '속초시',
      );

  test('보이는 순서와 일차, 분류와 식별자를 그대로 싣는다', () {
    final draft = draftOf([
      stop(order: 1, name: '속초해변', category: '해변', contentId: 'kakao:1'),
      stop(order: 2, name: '영금정', day: 2, contentId: 'kakao:2'),
    ]);

    expect(draft.blockedBy, isNull);
    final body = draft.request!.toJson();
    final places = body['places'] as List;
    expect(places.map((p) => (p as Map)['name']), ['속초해변', '영금정']);
    expect((places.first as Map)['category'], '해변');
    expect((places.first as Map)['content_id'], 'kakao:1');
    expect((places.last as Map)['day'], 2);
  });

  test('한 곳뿐이면 이을 구간이 없어 막는다', () {
    final draft = draftOf([stop(order: 1, name: '속초해변')]);

    expect(draft.blockedBy, ManualRouteBlock.tooFew);
    expect(draft.request, isNull);
  });

  test('서버 상한을 넘기면 막는다', () {
    final draft = draftOf([
      for (int i = 0; i < 11; i++) stop(order: i + 1, name: '장소$i'),
    ]);

    expect(draft.blockedBy, ManualRouteBlock.tooMany);
    expect(draft.request, isNull);
  });
}
