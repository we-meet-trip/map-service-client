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

  void setPendingTrip(TripGenerateResponse response) {
    pendingTrip = response;
    autoSaveOnNext = true;
  }

  void setLastPlan(TripPlanContext context) {
    lastPlan = context;
  }

  /// 저장한 일정을 예정·지난 것으로 갈라 둔다. 대화방을 만들 일정을 고르는
  /// 화면과 대화방에서 일정으로 건너뛰는 자리가 이 둘을 본다.
  final ValueNotifier<List<SavedTrip>> plannedTrips = ValueNotifier(const []);
  final ValueNotifier<List<SavedTrip>> completedTrips = ValueNotifier(const []);

  /// 서버에서 저장 목록을 받아 두 칸에 나눠 담는다.
  ///
  /// 목록 응답에는 방문지가 없어 여기서는 제목과 기간만 채운다. 상세를
  /// 일정마다 한 번씩 더 부르면 목록 한 번에 요청이 그 수만큼 늘어나는데,
  /// 고르는 화면은 제목과 기간만 그리므로 그 값을 치르지 않는다.
  Future<void> loadSaved() async {
    final items = await ScheduleApiService.instance.list();
    final today = DateTime.now();
    final planned = <SavedTrip>[];
    final done = <SavedTrip>[];
    for (final item in items) {
      final start = item.dateStart ?? item.createdAt ?? today;
      final end = item.dateEnd ?? start;
      final trip = SavedTrip(
        scheduleId: item.scheduleId,
        name: item.title.isEmpty ? '이름 없는 일정' : item.title,
        route: '',
        savedAt: item.createdAt ?? start,
        tripStartDate: start,
        tripEndDate: end,
        stops: const [],
        totalDurationMinutes: 0,
        chatRoomId: _roomOf[item.scheduleId.toString()],
      );
      (end.isBefore(DateTime(today.year, today.month, today.day)) ? done : planned)
          .add(trip);
    }
    plannedTrips.value = planned;
    completedTrips.value = done;
  }

  /// 일정에 붙은 대화방 번호. 목록을 다시 받아도 유지되도록 여기에 둔다.
  final Map<String, String> _roomOf = {};

  void setChatRoomId(String tripId, String roomId) {
    _roomOf[tripId] = roomId;
    plannedTrips.value = [
      for (final t in plannedTrips.value)
        t.id == tripId ? t.withChatRoom(roomId) : t,
    ];
    completedTrips.value = [
      for (final t in completedTrips.value)
        t.id == tripId ? t.withChatRoom(roomId) : t,
    ];
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

  /// 화면이 일정을 지목할 때 쓰는 값. 서버는 일정을 숫자로 세므로 그것을 쓴다.
  /// 아직 저장되지 않은 일정은 지목할 대상이 없어 빈 문자열이 된다.
  String get id => scheduleId?.toString() ?? '';

  SavedTrip withChatRoom(String roomId) => SavedTrip(
        scheduleId: scheduleId,
        name: name,
        route: route,
        savedAt: savedAt,
        tripStartDate: tripStartDate,
        tripEndDate: tripEndDate,
        stops: stops,
        totalDurationMinutes: totalDurationMinutes,
        chatRoomId: roomId,
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
