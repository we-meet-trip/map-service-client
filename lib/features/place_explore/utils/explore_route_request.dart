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

  final indexes = resolvePlanIndexes(plan, selectedIds);

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

/// 고른 식별자를 일정 안의 자리 번호로 옮긴다 — 일정 순서대로 정렬해서.
///
/// 알아볼 수 없는 식별자는 조용히 버린다. 일정이 바뀐 뒤에도 고른 흔적이
/// 남아 있을 수 있는데, 그것 때문에 진행이 막히면 안 된다.
List<int> resolvePlanIndexes(TripPlanContext plan, Set<String> selectedIds) {
  final indexes = <int>[];
  for (final id in selectedIds) {
    final index = planIndexOf(id);
    if (index == null || index < 0 || index >= plan.stops.length) continue;
    indexes.add(index);
  }
  indexes.sort();
  return indexes;
}

/// 남길 장소를 뺀 나머지를 새로 추천받는 요청으로 접은 결과.
class ExploreResearchDraft {
  /// 보낼 요청. 막혔으면 없다.
  final TripResearchRequest? request;

  /// 막힌 이유. 보낼 수 있으면 없다.
  final ExploreRouteBlock? blockedBy;

  /// 그대로 두기로 한 장소 수.
  final int keepCount;

  const ExploreResearchDraft({
    this.request,
    this.blockedBy,
    required this.keepCount,
  });
}

/// 고른 장소는 남기고 나머지는 새로 추천받는 요청을 짠다.
///
/// 하나도 고르지 않은 것도 정상이다 — 전부 새로 받겠다는 뜻이다. 제외
/// 목록에는 지금 일정의 장소를 전부 싣는다(남길 장소까지). 서버가 남길
/// 장소를 따로 세우므로 겹쳐도 사라지지 않고, 빠뜨리면 새로 뽑는 쪽에 같은
/// 곳이 다시 나온다.
///
/// [maxKeep] 은 서버가 받는 상한이다. 한 곳은 새로 와야 재탐색이므로 일정
/// 상한보다 하나 적다.
ExploreResearchDraft buildExploreResearchDraft({
  required TripPlanContext? plan,
  required Set<String> selectedIds,
  int maxKeep = 9,
}) {
  if (plan == null || plan.stops.isEmpty || !plan.canResearch) {
    return const ExploreResearchDraft(
      blockedBy: ExploreRouteBlock.noPlan,
      keepCount: 0,
    );
  }

  final indexes = resolvePlanIndexes(plan, selectedIds);
  if (indexes.length > maxKeep) {
    return ExploreResearchDraft(
      blockedBy: ExploreRouteBlock.tooMany,
      keepCount: indexes.length,
    );
  }

  // 식별자가 없는 장소는 남길 수 없다. 서버가 그 장소를 새로 뽑는 것들과
  // 맞대 볼 열쇠가 없어, 남겨 달라고 해도 같은 곳이 두 번 들어갈 수 있다.
  final keep = [
    for (final index in indexes)
      if ((plan.stops[index].contentId ?? '').isNotEmpty)
        SelectedPlace(
          name: plan.stops[index].name,
          address: plan.stops[index].address,
          latitude: plan.stops[index].latitude,
          longitude: plan.stops[index].longitude,
          day: plan.stops[index].day,
          category: plan.stops[index].category,
          contentId: plan.stops[index].contentId,
        ),
  ];

  final exclude = [
    for (final stop in plan.stops)
      if ((stop.contentId ?? '').isNotEmpty) stop.contentId!,
  ];

  return ExploreResearchDraft(
    request: TripResearchRequest(
      startDate: plan.startDate,
      endDate: plan.endDate,
      activeStartHour: plan.activeStartHour,
      activeEndHour: plan.activeEndHour,
      minBudget: plan.minBudget!,
      maxBudget: plan.maxBudget!,
      themes: plan.themes,
      transport: plan.transport,
      province: plan.province,
      city: plan.city,
      prevTripId: plan.tripId!,
      exclude: exclude,
      keep: keep,
    ),
    keepCount: keep.length,
  );
}
