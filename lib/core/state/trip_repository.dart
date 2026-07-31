import 'package:flutter/foundation.dart';
import '../api/trip_api_service.dart';

class TripRepository {
  TripRepository._();
  static final TripRepository instance = TripRepository._();

  final ValueNotifier<List<SavedTrip>> plannedTrips = ValueNotifier([_mockPlannedTrip]);
  final ValueNotifier<List<SavedTrip>> completedTrips = ValueNotifier([]);
  // 저장 탭 열릴 때 보여줄 탭 인덱스 (0: 예정, 1: 완료)
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

/// 매번 일정을 직접 만들지 않고도 저장 페이지를 테스트할 수 있도록 넣어둔 목 데이터.
/// 2일차까지 있어서 일차별 탭 UI도 이걸로 바로 확인 가능하다.
final _mockPlannedTrip = SavedTrip(
  name: '성수동 나들이',
  route: '서울숲 → 성수동 카페거리 → 서울숲 야시장',
  savedAt: DateTime.now(),
  tripStartDate: DateTime.now().add(const Duration(days: 7)),
  tripEndDate: DateTime.now().add(const Duration(days: 8)),
  totalDurationMinutes: 480,
  stops: [
    TripStop(
      order: 1,
      day: 1,
      name: '서울숲',
      address: '서울 성동구 뚝섬로 273',
      time: '10:00',
      latitude: 37.5443,
      longitude: 127.0374,
    ),
    TripStop(
      order: 2,
      day: 1,
      name: '성수동 카페거리',
      address: '서울 성동구 성수이로 89',
      time: '13:00',
      latitude: 37.5445,
      longitude: 127.0559,
    ),
    TripStop(
      order: 3,
      day: 2,
      name: '서울숲 야시장',
      address: '서울 성동구 뚝섬로 273-1',
      time: '18:00',
      latitude: 37.5449,
      longitude: 127.0389,
    ),
    TripStop(
      order: 4,
      day: 2,
      name: '성수 문화창작소',
      address: '서울 성동구 상원길 26',
      time: '20:00',
      latitude: 37.5426,
      longitude: 127.0567,
    ),
  ],
);

class SavedTrip {
  final String name;
  final String route;
  final DateTime savedAt;
  final DateTime tripStartDate;
  final DateTime tripEndDate;
  final List<TripStop> stops;
  final int totalDurationMinutes;

  SavedTrip({
    required this.name,
    required this.route,
    required this.savedAt,
    required this.tripStartDate,
    required this.tripEndDate,
    required this.stops,
    required this.totalDurationMinutes,
  });
}
