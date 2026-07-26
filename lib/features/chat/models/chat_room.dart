enum ChatRoomFilter { all, upcoming, past }

enum ChatRoomType { upcoming, past }

class ChatRoom {
  const ChatRoom({
    required this.id,
    required this.title,
    required this.lastMessage,
    required this.timeLabel,
    required this.type,
    this.hasUnread = false,
    this.participantCount = 1,
  });

  final String id;
  final String title;
  final String lastMessage;
  final String timeLabel;
  final ChatRoomType type;
  final bool hasUnread;
  final int participantCount;
}
