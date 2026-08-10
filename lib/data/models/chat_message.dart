/// 대화 한 줄.
///
/// 서버는 메시지에 따로 식별자를 매기지 않고 방 안에서의 순번(seq)만 준다.
/// 그래서 화면이 쓰는 id 도 방 번호와 순번을 엮어 만든다.
class ChatMessage {
  const ChatMessage({
    required this.roomId,
    required this.seq,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.text,
    required this.sentAt,
    required this.isMe,
    this.type = ChatMessageType.text,
    this.systemPayload,
    this.unreadCount = 0,
    this.clientMsgId,
    this.pending = false,
  });

  final int roomId;

  /// 방 안에서의 순번. 정렬과 읽음 위치의 기준이다.
  final int seq;

  /// 보낸 사람. 안내 메시지는 보낸 사람이 없다.
  final int? senderId;

  final String senderName;
  final String? senderAvatarUrl;
  final String text;
  final DateTime sentAt;
  final bool isMe;

  final ChatMessageType type;

  /// 안내 메시지의 구조화 정보. kind 로 종류를 가른다.
  final Map<String, dynamic>? systemPayload;

  /// 아직 이 메시지를 읽지 않은 사람 수.
  final int unreadCount;

  /// 보낼 때 붙인 임시 식별자. 서버가 되돌려 주면 이 값으로 짝을 짓는다.
  final String? clientMsgId;

  /// 아직 서버가 받았다고 알려 주지 않은 상태인지.
  final bool pending;

  /// 화면이 쓰는 식별자. 보내는 중이라 순번이 없으면 임시 식별자를 대신 쓴다.
  String get id => pending ? 'pending:$clientMsgId' : '$roomId:$seq';

  ChatMessage copyWith({int? unreadCount}) => ChatMessage(
        roomId: roomId,
        seq: seq,
        senderId: senderId,
        senderName: senderName,
        senderAvatarUrl: senderAvatarUrl,
        text: text,
        sentAt: sentAt,
        isMe: isMe,
        type: type,
        systemPayload: systemPayload,
        unreadCount: unreadCount ?? this.unreadCount,
        clientMsgId: clientMsgId,
        pending: pending,
      );
}

/// 대화 줄의 종류. 사람이 쓴 말과 서버가 남긴 안내를 가른다.
enum ChatMessageType { text, system }
