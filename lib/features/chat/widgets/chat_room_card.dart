import 'package:flutter/material.dart';
import '../../../data/models/chat_room.dart';

class ChatRoomCard extends StatelessWidget {
  const ChatRoomCard({
    super.key,
    required this.title,
    required this.lastMessage,
    required this.timeLabel,
    required this.type,
    required this.onTap,
    this.participantCount = 1,
    this.hasUnread = false,
  });

  final String title;
  final String lastMessage;
  final String timeLabel;
  final ChatRoomType type;
  final VoidCallback onTap;
  final int participantCount;
  final bool hasUnread;

  Color get _backgroundColor =>
      type == ChatRoomType.upcoming ? const Color(0xFFFDFDFE) : const Color(0xFFF5F5F5);

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _Avatar(participantCount: participantCount),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1C1C28),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF9797A6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFFB0B0BC),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
        if (hasUnread)
          Positioned(
            top: -5,
            right: 14,
            child: Container(
              width: 23,
              height: 23,
              decoration: BoxDecoration(
                color: const Color(0xFF6012DF),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFF8F7F9),
                  width: 5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.participantCount});

  final int participantCount;

  @override
  Widget build(BuildContext context) {
    if (participantCount >= 3) {
      return _GroupAvatar(participantCount: participantCount);
    }
    return const _SingleAvatar();
  }
}

class _SingleAvatar extends StatelessWidget {
  const _SingleAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(
        color: Color(0xFFE5E1F5),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _GroupAvatar extends StatelessWidget {
  const _GroupAvatar({required this.participantCount});

  final int participantCount;

  @override
  Widget build(BuildContext context) {
    final extra = participantCount - 2;
    return SizedBox(
      width: 66,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 6,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFD4CDEE),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: 18,
            top: 6,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFE5E1F5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Color(0xFF4A4A55),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '+$extra',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
