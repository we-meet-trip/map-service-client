import 'package:flutter/foundation.dart';
import '../api/schedule_api_service.dart';
import '../api/trip_api_service.dart';

class TripRepository {
  TripRepository._();
  static final TripRepository instance = TripRepository._();

  // 저장 탭 열릴 때 보여줄 탭 인덱스 (0: 예정, 1: 완료)
  final ValueNotifier<int> requestedTab = ValueNotifier(0);

  /// 저장 목록이 달라졌다는 신호.
  /// 저장 탭은 하단 탭의 한 칸이라 다시 열려도 새로 만들어지지 않는다.
  final ValueNotifier<int> savedRevision = ValueNotifier(0);

  void markSavedChanged() => savedRevision.value++;

  // 비로그인 저장 시도 → 로그인 후 복귀할 임시 일정
  TripGenerateResponse? pendingTrip;
  bool autoSaveOnNext = false;

  /// 방금 만든 일정과 그때 쓴 조건.
  ///
  /// 장소를 골라 동선만 다시 만들려면 그 일정의 장소 목록과 함께 기간·
  /// 이동수단·지역이 필요한데, 결과 화면에는 장소만 있고 나머지는 없다.
  /// 재탐색 화면은 라우트가 달라 화면 사이로 값을 넘길 수도 없어 여기에 둔다.
  TripPlanContext? lastPlan;

  final ValueNotifier<List<SavedTrip>> plannedTrips = ValueNotifier([]);
  final ValueNotifier<List<SavedTrip>> completedTrips = ValueNotifier([]);

  void setPendingTrip(TripGenerateResponse response) {
    pendingTrip = response;
    autoSaveOnNext = true;
  }

  void setLastPlan(TripPlanContext context) {
    lastPlan = context;
  }

  void setChatRoomId(String tripId, String roomId) {
    plannedTrips.value = plannedTrips.value
        .map((t) => t.id == tripId ? t.copyWith(chatRoomId: roomId) : t)
        .toList();
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

class SavedTrip {
  final int? scheduleId;
  final String name;
  final String route;
  final DateTime savedAt;
  final DateTime tripStartDate;
  final DateTime tripEndDate;
  final List<TripStop> stops;
  final int totalDurationMinutes;
  final String? chatRoomId;

  /// 추천 당시 반영하지 못한 조건 안내. 생성 화면과 같은 안내를 재열람에서도
  /// 보여준다. 없으면 빈 목록.
  final List<String> warnings;

  SavedTrip({
    this.scheduleId,
    required this.name,
    required this.route,
    required this.savedAt,
    required this.tripStartDate,
    required this.tripEndDate,
    required this.stops,
    required this.totalDurationMinutes,
    this.chatRoomId,
    this.warnings = const [],
  });

  String get id => scheduleId?.toString() ?? '';

  SavedTrip copyWith({String? chatRoomId}) => SavedTrip(
        scheduleId: scheduleId,
        name: name,
        route: route,
        savedAt: savedAt,
        tripStartDate: tripStartDate,
        tripEndDate: tripEndDate,
        stops: stops,
        totalDurationMinutes: totalDurationMinutes,
        chatRoomId: chatRoomId ?? this.chatRoomId,
        warnings: warnings,
      );

  factory SavedTrip.fromDetail(ScheduleDetail d) {
    final start = d.dateStart ?? DateTime.now();
    return SavedTrip(
      scheduleId: d.scheduleId,
      name: d.title.isEmpty ? '이름 없는 일정' : d.title,
      route: d.stops.map((s) => s.name).join(' → '),
      savedAt: d.createdAt ?? DateTime.now(),
      tripStartDate: start,
      tripEndDate: d.dateEnd ?? start,
      stops: d.stops,
      totalDurationMinutes: d.totalDurationMinutes,
      warnings: d.warnings,
    );
  }
}

final mockPlannedTrip = SavedTrip(
  scheduleId: 9001,
  name: '성수동 나들이',
  route: '성수역 → 카페 → 공원',
  savedAt: DateTime(2024, 6, 1),
  tripStartDate: DateTime(2024, 8, 10),
  tripEndDate: DateTime(2024, 8, 10),
  stops: const [],
  totalDurationMinutes: 180,
);

final mockCompletedTrip = SavedTrip(
  scheduleId: 9002,
  name: '여수 바다 여행',
  route: '여수역 → 해변 → 식당',
  savedAt: DateTime(2024, 5, 1),
  tripStartDate: DateTime(2024, 5, 10),
  tripEndDate: DateTime(2024, 5, 12),
  stops: const [],
  totalDurationMinutes: 360,
);
