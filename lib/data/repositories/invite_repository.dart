class InviteResolveResult {
  const InviteResolveResult({
    required this.success,
    required this.alreadyJoined,
    this.chatRoomId,
    this.errorMessage,
  });

  final bool success;
  final bool alreadyJoined;
  final String? chatRoomId;
  final String? errorMessage;
}

abstract class InviteRepository {
  Future<InviteResolveResult> resolveInvite(String token);
}

class MockInviteRepository implements InviteRepository {
  @override
  Future<InviteResolveResult> resolveInvite(String token) async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (token.contains('expired')) {
      return const InviteResolveResult(
        success: false,
        alreadyJoined: false,
        errorMessage: '만료된 초대 링크입니다.',
      );
    }

    if (token.contains('invalid')) {
      return const InviteResolveResult(
        success: false,
        alreadyJoined: false,
        errorMessage: '유효하지 않은 초대 링크입니다.',
      );
    }

    // 이미 참여한 케이스 시뮬레이션
    if (token.contains('joined')) {
      return const InviteResolveResult(
        success: true,
        alreadyJoined: true,
        chatRoomId: '1',
      );
    }

    // 기본: 속초 당일치기 방(id: '1') 참여 성공
    return const InviteResolveResult(
      success: true,
      alreadyJoined: false,
      chatRoomId: '1',
    );
  }
}
