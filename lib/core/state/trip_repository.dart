import 'package:flutter/foundation.dart';
import '../api/trip_api_service.dart';

class TripRepository {
  TripRepository._();
  static final TripRepository instance = TripRepository._();

  final ValueNotifier<List<SavedTrip>> plannedTrips = ValueNotifier([
    SavedTrip(
      id: 'mock_trip_001',
      name: '제주 3박 4일 여행',
      route: '제주',
      savedAt: DateTime(2026, 7, 20),
      tripStartDate: DateTime(2026, 8, 15),
      tripEndDate: DateTime(2026, 8, 18),
      stops: [],
      totalDurationMinutes: 0,
    ),
    SavedTrip(
      id: 'mock_trip_002',
      name: '부산 당일치기',
      route: '부산',
      savedAt: DateTime(2026, 7, 25),
      tripStartDate: DateTime(2026, 9, 6),
      tripEndDate: DateTime(2026, 9, 6),
      stops: [],
      totalDurationMinutes: 0,
    ),
  ]);
  // 저장 탭 열릴 때 보여줄 탭 인덱스 (0: 완료, 1: 예정)
  final ValueNotifier<int> requestedTab = ValueNotifier(0);

  void addTrip(SavedTrip trip) {
    plannedTrips.value = [...plannedTrips.value, trip];
  }

  void setChatRoomId(String tripId, String chatRoomId) {
    plannedTrips.value = plannedTrips.value.map((t) {
      return t.id == tripId ? t.copyWith(chatRoomId: chatRoomId) : t;
    }).toList();
  }
}

class SavedTrip {
  final String id;
  final String name;
  final String route;
  final DateTime savedAt;
  final DateTime tripStartDate;
  final DateTime tripEndDate;
  final List<TripStop> stops;
  final int totalDurationMinutes;
  final String? chatRoomId;

  SavedTrip({
    String? id,
    required this.name,
    required this.route,
    required this.savedAt,
    required this.tripStartDate,
    required this.tripEndDate,
    required this.stops,
    required this.totalDurationMinutes,
    this.chatRoomId,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  SavedTrip copyWith({String? chatRoomId}) => SavedTrip(
        id: id,
        name: name,
        route: route,
        savedAt: savedAt,
        tripStartDate: tripStartDate,
        tripEndDate: tripEndDate,
        stops: stops,
        totalDurationMinutes: totalDurationMinutes,
        chatRoomId: chatRoomId ?? this.chatRoomId,
      );
}
