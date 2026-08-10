import '../../../core/api/trip_api_service.dart';
import '../../../core/state/trip_repository.dart';
import '../models/place.dart';
import '../models/place_detail.dart';
import '../utils/plan_place_id.dart';
import 'place_explore_repository.dart';

/// 방금 만든 일정의 장소를 탐색 지도에 올린다.
///
/// 탐색은 이미 뽑아 둔 일정을 손보는 단계라 장소를 새로 받아올 곳이 없다.
/// 일정에 담긴 장소가 곧 지도에 찍을 후보이므로 그것을 그대로 쓴다.
class TripPlanPlaceExploreRepository implements PlaceExploreRepository {
  @override
  Future<List<Place>> getPlaces() async {
    final stops = _requireStops();
    return [
      for (int i = 0; i < stops.length; i++)
        Place(
          id: planPlaceId(i),
          name: stops[i].name,
          latitude: stops[i].latitude,
          longitude: stops[i].longitude,
          address: stops[i].address,
          category: stops[i].category,
        ),
    ];
  }

  @override
  Future<PlaceDetail> getPlaceDetail(String placeId) async {
    final stops = _requireStops();
    final index = planIndexOf(placeId);
    if (index == null || index < 0 || index >= stops.length) {
      throw StateError('일정에 없는 장소입니다: $placeId');
    }
    final stop = stops[index];
    // 지도가 이미 들고 있는 값만 채운다. 요약과 후기 자리는 비워 두어
    // 팝업이 기다림 없이 열린다.
    return PlaceDetail(
      id: placeId,
      name: stop.name,
      address: stop.address,
      category: stop.category,
    );
  }

  List<TripStop> _requireStops() {
    final stops = TripRepository.instance.lastPlan?.stops;
    if (stops == null || stops.isEmpty) {
      throw StateError('생성된 일정이 없습니다');
    }
    return stops;
  }
}
