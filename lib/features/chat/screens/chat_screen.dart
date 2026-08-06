import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../../common/theme/app_colors.dart';
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
      floatingActionButton: GestureDetector(
        onTap: () => context.push('/chat/new'),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFFDFDFE).withValues(alpha: 0.75),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF6E6C70).withValues(alpha: 0.028),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5C198A).withValues(alpha: 0.06),
                    blurRadius: 13.33,
                    offset: const Offset(0, 1.33),
                  ),
                ],
              ),
              child: Icon(
                PhosphorIcons.plus(PhosphorIconsStyle.bold),
                color: const Color(0xFF8D46ED),
                size: 28,
              ),
            ),
          ),
        ),
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
                        participants: room.participants,
                        participantCount: room.participantCount,
                        hasUnread: room.hasUnread,
                        onTap: () => context.push('/chat/${room.id}', extra: room).then((_) {
                          if (context.mounted) {
                            context.read<ChatRoomListProvider>().loadRooms();
                          }
                        }),
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
