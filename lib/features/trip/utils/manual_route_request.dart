import '../../../core/api/trip_api_service.dart';

/// 직접 고친 일정으로 동선을 만들 수 없는 이유.
enum ManualRouteBlock {
  /// 이을 구간이 없다. 장소가 두 곳은 있어야 한다.
  tooFew,

  /// 서버가 한 번에 받는 상한을 넘겼다.
  tooMany,
}

/// 직접 고친 일정을 동선 요청으로 접은 결과.
class ManualRouteDraft {
  /// 보낼 요청. 막혔으면 없다.
  final TripRouteRequest? request;

  /// 막힌 이유. 보낼 수 있으면 없다.
  final ManualRouteBlock? blockedBy;

  const ManualRouteDraft({this.request, this.blockedBy});
}

/// 직접 고친 방문지 목록으로 동선 요청을 짠다.
///
/// 순서는 화면에 보이는 그대로 담는다. 서버가 동선을 다시 짜며 순서를 바꿀
/// 수 있지만, 사용자가 옮겨 둔 순서가 출발점이 되어야 한다.
///
/// 방문 시각은 싣지 않는다. 장소를 더하거나 빼면 그 앞뒤가 전부 밀리므로
/// 시각은 서버가 다시 계산한다.
ManualRouteDraft buildManualRouteDraft({
  required List<TripStop> stops,
  required DateTime startDate,
  required DateTime endDate,
  required int activeStartHour,
  required int activeEndHour,
  required String transport,
  required String province,
  required String city,
  int minPlaces = 2,
  int maxPlaces = 10,
}) {
  if (stops.length < minPlaces) {
    return const ManualRouteDraft(blockedBy: ManualRouteBlock.tooFew);
  }
  if (stops.length > maxPlaces) {
    return const ManualRouteDraft(blockedBy: ManualRouteBlock.tooMany);
  }

  return ManualRouteDraft(
    request: TripRouteRequest(
      startDate: startDate,
      endDate: endDate,
      activeStartHour: activeStartHour,
      activeEndHour: activeEndHour,
      transport: transport,
      province: province,
      city: city,
      places: [
        for (final stop in stops)
          SelectedPlace(
            name: stop.name,
            address: stop.address,
            latitude: stop.latitude,
            longitude: stop.longitude,
            day: stop.day,
            category: stop.category,
            contentId: stop.contentId,
          ),
      ],
    ),
  );
}
