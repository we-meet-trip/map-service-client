import 'package:flutter/foundation.dart';
import '../api/trip_api_service.dart';

class TripRepository {
  TripRepository._();
  static final TripRepository instance = TripRepository._();

  final ValueNotifier<List<SavedTrip>> plannedTrips = ValueNotifier([mockPlannedTrip]);
  final ValueNotifier<List<SavedTrip>> completedTrips = ValueNotifier([mockCompletedTrip]);
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

  void setChatRoomId(String tripId, String chatRoomId) {
    plannedTrips.value = plannedTrips.value.map((t) {
      return t.id == tripId ? t.copyWith(chatRoomId: chatRoomId) : t;
    }).toList();
  }
}

/// 매번 일정을 직접 만들지 않고도 저장 페이지를 테스트할 수 있도록 넣어둔 목 데이터.
/// 2일차까지 있어서 일차별 탭 UI도 이걸로 바로 확인 가능하다.
final mockPlannedTrip = SavedTrip(
  id: DateTime(2025, 7, 1).microsecondsSinceEpoch.toString(),
  chatRoomId: DateTime(2025, 7, 1).microsecondsSinceEpoch.toString(),
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

final mockCompletedTrip = SavedTrip(
  id: DateTime(2025, 6, 1).microsecondsSinceEpoch.toString(),
  chatRoomId: DateTime(2025, 6, 1).microsecondsSinceEpoch.toString(),
  name: '여수 바다 여행',
  route: '오동도 → 이순신광장 → 여수 밤바다',
  savedAt: DateTime.now().subtract(const Duration(days: 30)),
  tripStartDate: DateTime.now().subtract(const Duration(days: 14)),
  tripEndDate: DateTime.now().subtract(const Duration(days: 14)),
  totalDurationMinutes: 360,
  stops: [
    TripStop(
      order: 1,
      day: 1,
      name: '오동도',
      address: '전남 여수시 오동도로 222',
      time: '10:00',
      latitude: 34.7441,
      longitude: 127.7647,
    ),
    TripStop(
      order: 2,
      day: 1,
      name: '이순신광장',
      address: '전남 여수시 이순신광장로 61',
      time: '14:00',
      latitude: 34.7378,
      longitude: 127.7447,
    ),
    TripStop(
      order: 3,
      day: 1,
      name: '여수 밤바다',
      address: '전남 여수시 수정동 해안로',
      time: '19:00',
      latitude: 34.7365,
      longitude: 127.7452,
    ),
  ],
);

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
