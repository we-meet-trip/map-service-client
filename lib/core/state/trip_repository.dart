import 'package:flutter/foundation.dart';
import '../api/trip_api_service.dart';

class TripRepository {
  TripRepository._();
  static final TripRepository instance = TripRepository._();

  final ValueNotifier<List<SavedTrip>> plannedTrips = ValueNotifier([]);

  final ValueNotifier<List<SavedTrip>> completedTrips = ValueNotifier([
    SavedTrip(
      name: '속초 당일치기',
      route: '속초 버스 터미널 → 속초해변 → 속초 중앙시장',
      savedAt: DateTime(2025, 7, 20),
      response: null, // NavigationScreen에서 placeholder 사용
    ),
  ]);

  // 저장 탭 열릴 때 보여줄 탭 인덱스 (0: 예정, 1: 완료)
  final ValueNotifier<int> requestedTab = ValueNotifier(0);

  void addTrip(SavedTrip trip) {
    plannedTrips.value = [...plannedTrips.value, trip];
  }
}

class SavedTrip {
  final String name;
  final String route;
  final DateTime savedAt;
  final TripGenerateResponse? response;

  SavedTrip({
    required this.name,
    required this.route,
    required this.savedAt,
    this.response,
  });
}
