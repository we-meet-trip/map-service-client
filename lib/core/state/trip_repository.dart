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

  void clearAccount() {
    pendingTrip = null;
    autoSaveOnNext = false;
    lastPlan = null;
    plannedTrips.value = [];
    completedTrips.value = [];
    requestedTab.value = 0;
    markSavedChanged();
  }

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

  void setChatRoomId(String tripId, int roomId) {
    plannedTrips.value = plannedTrips.value
        .map((t) => t.id == tripId ? t.copyWith(chatRoomId: roomId) : t)
        .toList();
  }
}

/// 방금 만든 일정과 그때 쓴 조건.
///
/// 고른 장소로 동선만 다시 만들 때 그대로 다시 보낸다 — 기간·활동 시간대·
/// 이동수단·지역은 장소를 바꿔도 그대로 유지되는 조건이다.
///
/// 재탐색은 여기에 더해 예산·테마·이 일정의 식별자까지 필요로 한다. 같은
/// 조건으로 다시 물어야 하는데, 그 값들을 들고 있지 않으면 사용자에게 입력을
/// 처음부터 다시 받는 수밖에 없다.
class TripPlanContext {
  final DateTime startDate;
  final DateTime endDate;
  final int activeStartHour;
  final int activeEndHour;
  final String transport;
  final String province;
  final String city;
  final List<TripStop> stops;

  /// 이 일정의 식별자(trip_id). 재탐색이 "무엇 말고"를 가리키는 열쇠다.
  /// 저장된 일정을 열어 만든 맥락에는 없을 수 있다.
  final String? tripId;

  /// 이 일정을 만들 때 쓴 예산·테마. 재탐색에 그대로 다시 싣는다.
  /// 동선만 다시 만든 맥락에는 없다(그 요청은 조건을 받지 않는다).
  final int? minBudget;
  final int? maxBudget;
  final List<String> themes;

  const TripPlanContext({
    required this.startDate,
    required this.endDate,
    required this.activeStartHour,
    required this.activeEndHour,
    required this.transport,
    required this.province,
    required this.city,
    required this.stops,
    this.tripId,
    this.minBudget,
    this.maxBudget,
    this.themes = const [],
  });

  /// 재탐색을 걸 수 있는 맥락인지. 식별자와 조건이 모두 있어야 같은 조건으로
  /// 다시 물을 수 있다.
  bool get canResearch =>
      tripId != null &&
      tripId!.isNotEmpty &&
      minBudget != null &&
      maxBudget != null &&
      themes.isNotEmpty;
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
  final int? chatRoomId;

  /// 추천 당시 반영하지 못한 조건 안내. 생성 화면과 같은 안내를 재열람에서도
  /// 보여준다. 없으면 빈 목록.
  final List<String> warnings;

  /// 이 일정을 고칠 때 필요한 조건. 장소를 더하거나 빼면 동선을 새로 짜야
  /// 하는데 그 요청이 지역·이동수단·활동 시간대를 요구한다. 지역을 모르는
  /// 옛 일정에는 없으므로, 그때는 고치기 입구를 감춘다.
  final String? province;
  final String? city;
  final String? transport;
  final int? activeStartHour;
  final int? activeEndHour;

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
    this.province,
    this.city,
    this.transport,
    this.activeStartHour,
    this.activeEndHour,
  });

  String get id => scheduleId?.toString() ?? '';

  /// 고칠 수 있는 일정인지. 지역을 모르면 동선을 새로 짤 수 없다.
  bool get canEdit =>
      scheduleId != null &&
      (province ?? '').isNotEmpty &&
      (city ?? '').isNotEmpty;

  SavedTrip copyWith({int? chatRoomId}) => SavedTrip(
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
    province: province,
    city: city,
    transport: transport,
    activeStartHour: activeStartHour,
    activeEndHour: activeEndHour,
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
      province: d.province,
      city: d.city,
      transport: d.transport,
      activeStartHour: d.activeStartHour,
      activeEndHour: d.activeEndHour,
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
