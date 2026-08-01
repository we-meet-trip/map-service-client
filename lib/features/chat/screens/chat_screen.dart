import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../common/theme/app_colors.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/schedule_api_service.dart';
import '../providers/chat_room_list_provider.dart';
import '../widgets/chat_room_card.dart';
import '../widgets/chat_room_filter_tabs.dart';

class ChatRoomListScreen extends StatefulWidget {
  const ChatRoomListScreen({super.key});

  @override
  State<ChatRoomListScreen> createState() => _ChatRoomListScreenState();
}

class _ChatRoomListScreenState extends State<ChatRoomListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatRoomListProvider>().loadRooms();
    });
  }

  /// 저장한 일정을 골라 대화방을 만든다.
  ///
  /// 대화방은 일정에 매여 있고, 자기가 저장한 일정에만 만들 수 있다. 그래서
  /// 방을 새로 만드는 유일한 길은 저장 목록에서 고르는 것이다.
  Future<void> _showCreateRoomSheet() async {
    List<ScheduleSummary> schedules;
    try {
      schedules = await ScheduleApiService.instance.list();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (!mounted) return;
    if (schedules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('먼저 일정을 저장하면 그 일정으로 대화방을 만들 수 있어요.'),
      ));
      return;
    }
    final picked = await showModalBottomSheet<ScheduleSummary>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                '어떤 일정의 대화방인가요?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final s in schedules)
                    ListTile(
                      title: Text(s.title.isEmpty ? '이름 없는 일정' : s.title),
                      subtitle: s.dateStart == null
                          ? null
                          : Text('${s.dateStart!.month}월 ${s.dateStart!.day}일 시작'),
                      onTap: () => Navigator.of(sheetContext).pop(s),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final provider = context.read<ChatRoomListProvider>();
    final roomId = await provider.createRoom(picked.scheduleId);
    if (!mounted) return;
    if (roomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(provider.errorMessage ?? '대화방을 만들지 못했어요.'),
      ));
    }
  }

  static String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(dt.year, dt.month, dt.day);
    if (date == today) return '오늘';
    if (date == yesterday) return '어제';
    return '${dt.month}월 ${dt.day}일';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F8FA),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateRoomSheet,
        backgroundColor: AppColors.primaryScale[500],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('대화방 만들기'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                '대화방',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1C1C28),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                '여행 멤버들과 실시간으로 소통하세요.',
                style: TextStyle(fontSize: 13, color: AppColors.neutralScale[300]),
              ),
            ),
            Consumer<ChatRoomListProvider>(
              builder: (context, provider, _) => ChatRoomFilterTabs(
                selected: provider.filter,
                onChanged: provider.setFilter,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Consumer<ChatRoomListProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final rooms = provider.filteredRooms;
                  if (rooms.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          provider.errorMessage ??
                              '아직 대화방이 없어요.\n저장한 일정으로 만들어 보세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: AppColors.neutralScale[300],
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: rooms.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final room = rooms[index];
                      return ChatRoomCard(
                        title: room.title,
                        lastMessage: room.lastMessage,
                        timeLabel: _formatTime(room.lastMessageAt),
                        type: room.type,
                        participantCount: room.participantCount,
                        onTap: () => context.push('/chat/${room.id}', extra: room),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
