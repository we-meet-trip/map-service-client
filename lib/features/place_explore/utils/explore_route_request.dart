import '../../../core/api/trip_api_service.dart';
import '../../../core/state/trip_repository.dart';
import 'plan_place_id.dart';

/// 고른 장소로 동선을 만들 수 없는 이유.
enum ExploreRouteBlock {
  /// 손볼 일정이 없다. 화면을 건너뛰고 들어왔을 때다.
  noPlan,

  /// 고른 곳이 너무 적다.
  tooFew,

  /// 고른 곳이 너무 많다. 서버가 받는 상한을 넘겼다.
  tooMany,
}

/// 고른 장소를 동선 요청으로 접은 결과.
class ExploreRouteDraft {
  /// 보낼 요청. 막혔으면 없다.
  final TripRouteRequest? request;

  /// 막힌 이유. 보낼 수 있으면 없다.
  final ExploreRouteBlock? blockedBy;

  /// 실제로 요청에 담긴 장소 수. 알아볼 수 없는 선택은 빼고 센다.
  final int placeCount;

  const ExploreRouteDraft({
    this.request,
    this.blockedBy,
    required this.placeCount,
  });
}

/// 탐색에서 고른 장소로 동선을 다시 만들 요청을 짠다.
///
/// 담는 순서는 일정 순서다. 고른 순서는 화면 어디에도 드러나지 않고, 서버가
/// 어차피 동선을 다시 짜며 순서를 바꾼다. 남는 요구는 같은 선택이면 같은
/// 요청이 나오는 것뿐이다.
///
/// [minPlaces] 는 탐색 화면이 요구하는 최소 개수, [maxPlaces] 는 서버가 받는
/// 상한이다. 상한을 넘겨 보내면 서버가 영문 오류 문구로 거절한다.
ExploreRouteDraft buildExploreRouteDraft({
  required TripPlanContext? plan,
  required Set<String> selectedIds,
  int minPlaces = 3,
  int maxPlaces = 10,
}) {
  if (plan == null || plan.stops.isEmpty) {
    return const ExploreRouteDraft(
      blockedBy: ExploreRouteBlock.noPlan,
      placeCount: 0,
    );
  }

  // 알아볼 수 없는 식별자는 조용히 버린다. 일정이 바뀐 뒤에도 고른 흔적이
  // 남아 있을 수 있는데, 그것 때문에 진행이 막히면 안 된다.
  final indexes = <int>[];
  for (final id in selectedIds) {
    final index = planIndexOf(id);
    if (index == null || index < 0 || index >= plan.stops.length) continue;
    indexes.add(index);
  }
  indexes.sort();

  if (indexes.length < minPlaces) {
    return ExploreRouteDraft(
      blockedBy: ExploreRouteBlock.tooFew,
      placeCount: indexes.length,
    );
  }
  if (indexes.length > maxPlaces) {
    return ExploreRouteDraft(
      blockedBy: ExploreRouteBlock.tooMany,
      placeCount: indexes.length,
    );
  }

  final places = [
    for (final index in indexes)
      SelectedPlace(
        name: plan.stops[index].name,
        address: plan.stops[index].address,
        latitude: plan.stops[index].latitude,
        longitude: plan.stops[index].longitude,
        day: plan.stops[index].day,
        category: plan.stops[index].category,
      ),
  ];

  return ExploreRouteDraft(
    request: TripRouteRequest(
      startDate: plan.startDate,
      endDate: plan.endDate,
      activeStartHour: plan.activeStartHour,
      activeEndHour: plan.activeEndHour,
      transport: plan.transport,
      province: plan.province,
      city: plan.city,
      places: places,
    ),
    placeCount: places.length,
  );
}
