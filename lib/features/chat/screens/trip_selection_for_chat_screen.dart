import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/next_button.dart';
import '../../auth/widgets/signup_back_button.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/schedule_api_service.dart';
import '../../../core/state/trip_repository.dart';
import '../../../data/repositories/chat_repository.dart';
import '../providers/chat_room_list_provider.dart';
import '../widgets/trip_selectable_card.dart';

class TripSelectionForChatScreen extends StatefulWidget {
  const TripSelectionForChatScreen({super.key});

  @override
  State<TripSelectionForChatScreen> createState() =>
      _TripSelectionForChatScreenState();
}

class _TripSelectionForChatScreenState
    extends State<TripSelectionForChatScreen> {
  String? _selectedTripId;
  bool _loading = false;
  bool _tripsLoading = true;
  bool _tripsFailed = false;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  /// 고를 수 있는 일정을 서버에서 받아 채운다.
  ///
  /// 저장한 일정은 서버에만 남고 앱은 들고 있지 않다. 받아 두지 않으면 목록이
  /// 비어 보여 대화방을 만들 길이 없다. 이미 방이 있는 일정은 방 번호를 붙여
  /// 두면 아래 목록이 알아서 걸러낸다.
  Future<void> _loadTrips() async {
    setState(() {
      _tripsLoading = true;
      _tripsFailed = false;
    });
    // 저장소는 기다리기 전에 집어 둔다. 기다린 뒤에 context 를 다시 만지면
    // 그 사이 화면이 사라졌을 때 없는 것을 붙잡게 된다.
    final chatRepository = context.read<ChatRepository>();
    try {
      final schedules = await ScheduleApiService.instance.list();
      final rooms = await chatRepository.getChatRooms();
      final roomBySchedule = {for (final r in rooms) r.scheduleId: r.id};
      if (!mounted) return;
      TripRepository.instance.plannedTrips.value = [
        for (final s in schedules)
          SavedTrip(
            scheduleId: s.scheduleId,
            name: s.title.isEmpty ? '이름 없는 일정' : s.title,
            // 목록 카드는 이름과 기간만 그린다. 방문지는 방을 만든 뒤 상세에서 받는다.
            route: '',
            savedAt: s.createdAt ?? DateTime.now(),
            tripStartDate: s.dateStart ?? DateTime.now(),
            tripEndDate: s.dateEnd ?? s.dateStart ?? DateTime.now(),
            stops: const [],
            totalDurationMinutes: 0,
            chatRoomId: roomBySchedule[s.scheduleId],
          ),
      ];
      setState(() => _tripsLoading = false);
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _tripsLoading = false;
        _tripsFailed = true;
      });
    }
  }

  Future<void> _createChatRoom() async {
    final trip = TripRepository.instance.plannedTrips.value
        .firstWhere((t) => t.id == _selectedTripId);

    setState(() => _loading = true);
    try {
      final repo = context.read<ChatRepository>();
      final room = await repo.createChatRoomForSchedule(trip.scheduleId!);
      TripRepository.instance.setChatRoomId(trip.id, room.id);
      if (!mounted) return;
      context.read<ChatRoomListProvider>().loadRooms();
      context.go('/chat/${room.id}', extra: room);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: SignupBackButton(onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '일정 선택',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.neutralScale[600],
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '대화방을 생성할 일정을 선택해주세요.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.neutralScale[500],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ValueListenableBuilder<List<SavedTrip>>(
                valueListenable: TripRepository.instance.plannedTrips,
                builder: (context, trips, _) {
                  if (_tripsLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final available =
                      trips.where((t) => t.chatRoomId == null).toList();
                  if (available.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _tripsFailed
                                ? '일정을 불러오지 못했어요.'
                                : '연결할 수 있는 예정 일정이 없어요.\n여행 계획에서 일정을 먼저 저장해보세요!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.neutralScale[300],
                              height: 1.6,
                            ),
                          ),
                          if (_tripsFailed)
                            TextButton(
                              onPressed: _loadTrips,
                              child: const Text('다시 시도'),
                            ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: available.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => TripSelectableCard(
                      trip: available[i],
                      isSelected: _selectedTripId == available[i].id,
                      hasSelection: _selectedTripId != null,
                      onTap: () =>
                          setState(() => _selectedTripId = available[i].id),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 42),
              child: NextButton(
                label: _loading ? '생성 중...' : '대화방 생성하기',
                onPressed: (_selectedTripId != null && !_loading)
                    ? _createChatRoom
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
