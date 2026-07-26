import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';
import '../models/chat_room.dart';
import '../widgets/chat_room_card.dart';
import '../widgets/chat_room_filter_tabs.dart';

class ChatRoomListScreen extends StatefulWidget {
  const ChatRoomListScreen({super.key});

  @override
  State<ChatRoomListScreen> createState() => _ChatRoomListScreenState();
}

class _ChatRoomListScreenState extends State<ChatRoomListScreen> {
  ChatRoomFilter _filter = ChatRoomFilter.all;

  static const _rooms = [
    ChatRoom(
      id: '1',
      title: '속초 당일치기',
      lastMessage: '다들 몇 시에 출발해요?',
      timeLabel: '어제',
      type: ChatRoomType.upcoming,
      participantCount: 2,
    ),
    ChatRoom(
      id: '2',
      title: '강릉 바다 여행',
      lastMessage: '숙소 예약 완료했어요 🎉',
      timeLabel: '오늘',
      type: ChatRoomType.upcoming,
      participantCount: 1,
    ),
    ChatRoom(
      id: '3',
      title: '춘천 닭갈비 투어',
      lastMessage: '진짜 맛있었다ㅠㅠ 또 가고 싶어요!!',
      timeLabel: '7월 11일',
      type: ChatRoomType.past,
      participantCount: 5,
    ),
    ChatRoom(
      id: '4',
      title: '춘천 1박2일',
      lastMessage: '사진 공유 링크 올려둘게요',
      timeLabel: '6월 28일',
      type: ChatRoomType.past,
      participantCount: 1,
    ),
  ];

  List<ChatRoom> get _filtered {
    if (_filter == ChatRoomFilter.all) return _rooms;
    final targetType = _filter == ChatRoomFilter.upcoming
        ? ChatRoomType.upcoming
        : ChatRoomType.past;
    return _rooms.where((r) => r.type == targetType).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F8FA),
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
            ChatRoomFilterTabs(
              selected: _filter,
              onChanged: (f) => setState(() => _filter = f),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: _filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final room = _filtered[index];
                  return ChatRoomCard(
                    title: room.title,
                    lastMessage: room.lastMessage,
                    timeLabel: room.timeLabel,
                    type: room.type,
                    participantCount: room.participantCount,
                    onTap: () {
                      // TODO: context.push('/chat/${room.id}')
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
