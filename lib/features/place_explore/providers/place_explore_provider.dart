import 'package:flutter/foundation.dart';
import '../data/place_explore_repository.dart';
import '../models/place.dart';
import '../models/place_detail.dart';

enum PlaceExploreStatus { idle, loading, success, error }

class PlaceExploreProvider extends ChangeNotifier {
  PlaceExploreProvider(this._repository);

  final PlaceExploreRepository _repository;

  PlaceExploreStatus status = PlaceExploreStatus.idle;
  List<Place> places = [];
  String? errorMessage;

  final Map<String, PlaceDetail> _detailCache = {};
  final Set<String> _selectedIds = {};
  Set<String> _committedIds = {};

  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);
  Set<String> get committedIds => Set.unmodifiable(_committedIds);

  PlaceDetail? cachedDetail(String id) => _detailCache[id];

  Future<void> loadPlaces() async {
    if (status == PlaceExploreStatus.loading ||
        status == PlaceExploreStatus.success) {
      return;
    }
    status = PlaceExploreStatus.loading;
    notifyListeners();
    try {
      places = await _repository.getPlaces();
      status = PlaceExploreStatus.success;
    } catch (e) {
      errorMessage = e.toString();
      status = PlaceExploreStatus.error;
    }
    notifyListeners();
  }

  Future<PlaceDetail?> loadDetail(String id) async {
    if (_detailCache.containsKey(id)) return _detailCache[id];
    try {
      final detail = await _repository.getPlaceDetail(id);
      _detailCache[id] = detail;
      notifyListeners();
      return detail;
    } catch (_) {
      return null;
    }
  }

  Future<void> loadAllDetails() async {
    for (final place in places) {
      await loadDetail(place.id);
    }
  }

  void togglePlace(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  void commitSelection() {
    _committedIds = Set.from(_selectedIds);
  }

  void resetToCommitted() {
    _selectedIds
      ..clear()
      ..addAll(_committedIds);
    notifyListeners();
  }

  void reset() {
    status = PlaceExploreStatus.idle;
    places = [];
    errorMessage = null;
    _detailCache.clear();
    _selectedIds.clear();
    _committedIds = {};
    notifyListeners();
  }
}
