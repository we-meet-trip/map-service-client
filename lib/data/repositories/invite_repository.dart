/// 초대 링크를 눌렀을 때의 결말.
class InviteResolveResult {
  const InviteResolveResult({
    required this.success,
    required this.alreadyJoined,
    this.loginRequired = false,
    this.chatRoomId,
    this.roomTitle,
    this.participantCount,
    this.expiresAt,
    this.errorMessage,
  });

  /// 방으로 들어가도 되는 상태인지.
  final bool success;

  /// 이미 들어가 있던 사람인지. 이 경우도 실패가 아니다.
  final bool alreadyJoined;

  /// 로그인부터 해야 하는 상태인지. 오류가 아니라 순서의 문제다.
  final bool loginRequired;

  final int? chatRoomId;

  /// 무엇에 초대받았는지. 로그인 전에도 보여 줄 수 있도록 미리보기에서 받아 둔다.
  final String? roomTitle;

  final int? participantCount;
  final DateTime? expiresAt;

  final String? errorMessage;
}

/// 초대 링크 해석기.
abstract class InviteRepository {
  /// 링크가 가리키는 방을 확인만 한다. 로그인 없이도 된다.
  Future<InviteResolveResult> preview(String token);

  /// 링크로 방에 들어간다. 로그인이 필요하다.
  Future<InviteResolveResult> join(String token);
}
