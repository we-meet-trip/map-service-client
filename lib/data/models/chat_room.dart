enum ChatRoomType { upcoming, past }

class ChatRoom {
  const ChatRoom({
    required this.id,
    required this.title,
    this.avatarUrls = const [],
    this.participantCount = 1,
    required this.type,
    this.hasUnread = false,
    required this.lastMessage,
    required this.lastMessageAt,
    this.linkedTripId,
  });

  final String id;
  final String title;
  final List<String> avatarUrls;
  final int participantCount;
  final ChatRoomType type;
  final bool hasUnread;
  final String lastMessage;
  final DateTime lastMessageAt;
  final String? linkedTripId;

  ChatRoom copyWith({bool? hasUnread, String? lastMessage, DateTime? lastMessageAt}) => ChatRoom(
        id: id,
        title: title,
        avatarUrls: avatarUrls,
        participantCount: participantCount,
        type: type,
        hasUnread: hasUnread ?? this.hasUnread,
        lastMessage: lastMessage ?? this.lastMessage,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        linkedTripId: linkedTripId,
      );
}
