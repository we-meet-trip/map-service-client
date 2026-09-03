/// 발급된 초대 링크.
class InviteLink {
  const InviteLink({required this.url, required this.expiresAt});

  /// 그대로 공유하면 되는 주소. 서버가 만든 것을 그대로 쓴다.
  final String url;

  /// 이 링크가 언제까지 유효한지.
  final DateTime? expiresAt;
}

/// 초대 링크 발급기.
abstract class InviteLinkRepository {
  /// 방의 초대 링크를 발급한다.
  ///
  /// 부를 때마다 새 링크가 나오고 **이전 링크는 즉시 죽는다.** 화면은 결과를
  /// 들고 있다가 다시 보여 줘야 하며, 열 때마다 부르면 방금 보낸 주소를
  /// 매번 끊게 된다.
  Future<InviteLink> generateInviteLink(int roomId);
}
