import 'user.dart';

/// 목록에서 방을 가르는 기준. 아직 다닐 여행이면 upcoming, 끝난 여행이면 past.
enum ChatRoomType { upcoming, past }

/// 화면이 다루는 채팅방.
///
/// 서버의 방 번호와 일정 번호는 서로 다른 값이다. 둘을 같은 것으로 두면 "일정
/// 보러가기"처럼 일정을 찾아가는 자리가 조용히 아무 데도 닿지 않게 된다.
class ChatRoom {
  const ChatRoom({
    required this.id,
    required this.scheduleId,
    required this.title,
    this.participants = const [],
    this.participantCount = 1,
    this.readOnly = false,
    this.expiresAt,
    this.latestSeq = 0,
    this.unreadCount = 0,
    this.lastMessage = '',
    this.lastMessageAt,
  });

  /// 방 번호.
  final int id;

  /// 이 방이 매달린 일정 번호.
  final int scheduleId;

  final String title;

  /// 참가자 목록. 목록 화면에서는 비어 있고 방에 들어가야 채워진다.
  final List<User> participants;

  final int participantCount;

  /// 보관 전용으로 넘어갔는지.
  final bool readOnly;

  /// 방이 닫히는 시각.
  final DateTime? expiresAt;

  /// 방의 최신 메시지 순번.
  final int latestSeq;

  final int unreadCount;

  final String lastMessage;

  /// 마지막 대화 시각. 아직 아무도 말하지 않은 방은 비어 있다.
  final DateTime? lastMessageAt;

  bool get hasUnread => unreadCount > 0;

  /// 지난 방인지 여부는 저장하지 않고 그때그때 따진다.
  ///
  /// 보관 전용이 되었거나 만료 시각을 지났으면 지난 방이다. 값으로 들고 있으면
  /// 화면을 열어 둔 채 자정을 넘겼을 때 실제 상태와 어긋난다.
  ChatRoomType get type {
    final closesAt = expiresAt;
    final ended = readOnly || (closesAt != null && !DateTime.now().isBefore(closesAt));
    return ended ? ChatRoomType.past : ChatRoomType.upcoming;
  }

  /// 목록 정렬에 쓰는 시각. 대화가 없으면 방이 뒤로 가도록 아주 과거로 둔다.
  DateTime get sortedAt => lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  ChatRoom copyWith({
    List<User>? participants,
    int? participantCount,
    bool? readOnly,
    int? latestSeq,
    int? unreadCount,
    String? lastMessage,
    DateTime? lastMessageAt,
  }) =>
      ChatRoom(
        id: id,
        scheduleId: scheduleId,
        title: title,
        participants: participants ?? this.participants,
        participantCount: participantCount ?? this.participantCount,
        readOnly: readOnly ?? this.readOnly,
        expiresAt: expiresAt,
        latestSeq: latestSeq ?? this.latestSeq,
        unreadCount: unreadCount ?? this.unreadCount,
        lastMessage: lastMessage ?? this.lastMessage,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      );
}
