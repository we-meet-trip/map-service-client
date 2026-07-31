import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/next_button.dart';
import '../../auth/widgets/signup_back_button.dart';
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

  Future<void> _createChatRoom() async {
    final trip = TripRepository.instance.plannedTrips.value
        .firstWhere((t) => t.id == _selectedTripId);

    setState(() => _loading = true);
    try {
      final repo = context.read<ChatRepository>();
      final room = await repo.createChatRoomForTrip(trip.id, trip.name);
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
                    '알정 선택',
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
                  final available =
                      trips.where((t) => t.chatRoomId == null).toList();
                  if (available.isEmpty) {
                    return Center(
                      child: Text(
                        '연결할 수 있는 예정 일정이 없어요.\n여행 계획에서 일정을 먼저 저장해보세요!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.neutralScale[300],
                          height: 1.6,
                        ),
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
