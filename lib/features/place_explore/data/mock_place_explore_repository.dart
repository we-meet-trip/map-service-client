import '../models/place.dart';
import '../models/place_detail.dart';
import 'place_explore_repository.dart';
import 'place_mock.dart';
import 'place_detail_mock.dart';

class MockPlaceExploreRepository implements PlaceExploreRepository {
  @override
  Future<List<Place>> getPlaces() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return mockPlaces;
  }

  @override
  Future<PlaceDetail> getPlaceDetail(String placeId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final detail = mockPlaceDetails[placeId];
    if (detail == null) throw Exception('Place not found: $placeId');
    return detail;
  }
}
