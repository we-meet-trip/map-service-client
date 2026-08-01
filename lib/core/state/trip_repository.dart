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

  /// 방금 만든 일정과 그때 쓴 조건.
  ///
  /// 장소를 골라 동선만 다시 만들려면 그 일정의 장소 목록과 함께 기간·
  /// 이동수단·지역이 필요한데, 결과 화면에는 장소만 있고 나머지는 없다.
  /// 재탐색 화면은 라우트가 달라 화면 사이로 값을 넘길 수도 없어 여기에 둔다.
  TripPlanContext? lastPlan;

  void setPendingTrip(TripGenerateResponse response) {
    pendingTrip = response;
    autoSaveOnNext = true;
  }

  void setLastPlan(TripPlanContext context) {
    lastPlan = context;
  }

  void addTrip(SavedTrip trip) {
    plannedTrips.value = [...plannedTrips.value, trip];
  }
}

/// 방금 만든 일정과 그때 쓴 조건.
///
/// 고른 장소로 동선만 다시 만들 때 그대로 다시 보낸다 — 기간·활동 시간대·
/// 이동수단·지역은 장소를 바꿔도 그대로 유지되는 조건이다.
class TripPlanContext {
  final DateTime startDate;
  final DateTime endDate;
  final int activeStartHour;
  final int activeEndHour;
  final String transport;
  final String province;
  final String city;
  final List<TripStop> stops;

  const TripPlanContext({
    required this.startDate,
    required this.endDate,
    required this.activeStartHour,
    required this.activeEndHour,
    required this.transport,
    required this.province,
    required this.city,
    required this.stops,
  });
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
