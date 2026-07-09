import 'package:flutter/foundation.dart';
import '../api/trip_api_service.dart';

class TripRepository {
  TripRepository._();
  static final TripRepository instance = TripRepository._();

  final ValueNotifier<List<SavedTrip>> plannedTrips = ValueNotifier([]);
  // 저장 탭 열릴 때 보여줄 탭 인덱스 (0: 완료, 1: 예정)
  final ValueNotifier<int> requestedTab = ValueNotifier(0);

  // 비로그인 저장 시도 → 로그인 후 복귀할 임시 일정
  TripGenerateResponse? pendingTrip;
  bool autoSaveOnNext = false;

  void setPendingTrip(TripGenerateResponse response) {
    pendingTrip = response;
    autoSaveOnNext = true;
  }

  void addTrip(SavedTrip trip) {
    plannedTrips.value = [...plannedTrips.value, trip];
  }
}

class SavedTrip {
  final String name;
  final String route;
  final DateTime savedAt;

  SavedTrip({
    required this.name,
    required this.route,
    required this.savedAt,
  });
}
