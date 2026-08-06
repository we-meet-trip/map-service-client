import '../models/place.dart';
import '../models/place_detail.dart';

abstract class PlaceExploreRepository {
  Future<List<Place>> getPlaces();
  Future<PlaceDetail> getPlaceDetail(String placeId);
}
