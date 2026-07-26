import 'package:flutter/material.dart';
import '../models/chat_room.dart';

class ChatRoomFilterTabs extends StatelessWidget {
  const ChatRoomFilterTabs({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final ChatRoomFilter selected;
  final ValueChanged<ChatRoomFilter> onChanged;

  static const _tabs = [
    (label: '전체', filter: ChatRoomFilter.all),
    (label: '예정된 여행', filter: ChatRoomFilter.upcoming),
    (label: '지난 여행', filter: ChatRoomFilter.past),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tab = _tabs[index];
          final isSelected = selected == tab.filter;
          return GestureDetector(
            onTap: () => onChanged(tab.filter),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFEDE4FB) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tab.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF7C4DFF) : const Color(0xFFB0B0BC),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
