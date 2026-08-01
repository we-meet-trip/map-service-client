import '../../core/api/api_client.dart';
import 'invite_link_repository.dart';
import 'invite_repository.dart';

/// 초대 링크를 서버에서 받아 온다.
///
/// 링크의 유효 기간은 **방이 살아 있는 동안**이다. 별도의 기간을 두지 않으며,
/// 방이 보관 상태로 넘어가거나 링크를 새로 발급하면 이전 링크는 죽는다.
class ApiInviteLinkRepository implements InviteLinkRepository {
  final _api = ApiClient.instance;

  /// 마지막으로 받은 만료 시각. 화면이 안내 문구에 쓴다.
  DateTime? lastExpiresAt;

  @override
  Future<String> generateInviteLink(String roomId, String roomTitle) async {
    final json = await _api.post('/api/v1/chat/rooms/$roomId/invite');
    final expires = json['expires_at'];
    lastExpiresAt =
        expires is String ? DateTime.tryParse(expires) : null;
    return json['url'] as String? ?? '';
  }
}

/// 초대 링크로 방에 들어간다.
///
/// 서버가 실패 사유를 코드로 갈라 주므로 화면 문구도 그에 맞춘다 —
/// 만료·폐기·정원 초과·강퇴는 사용자가 할 수 있는 일이 각각 다르다.
class ApiInviteRepository implements InviteRepository {
  final _api = ApiClient.instance;

  @override
  Future<InviteResolveResult> resolveInvite(String token) async {
    try {
      final json = await _api.post('/api/v1/chat/invites/$token/join');
      return InviteResolveResult(
        success: true,
        alreadyJoined: false,
        chatRoomId: '${json['room_id']}',
      );
    } on ApiException catch (e) {
      // 이미 들어가 있는 방이면 실패가 아니다. 방 번호를 따로 알아내
      // 그대로 들여보낸다.
      if (e.code == 'CHAT_007') {
        final roomId = await _roomIdOf(token);
        return InviteResolveResult(
          success: roomId != null,
          alreadyJoined: true,
          chatRoomId: roomId,
          errorMessage: roomId == null ? e.message : null,
        );
      }
      return InviteResolveResult(
        success: false,
        alreadyJoined: false,
        errorMessage: _messageFor(e),
      );
    }
  }

  /// 링크가 가리키는 방 번호. 참가 전에 들어갈 수 있는 방인지도 함께 본다.
  Future<String?> _roomIdOf(String token) async {
    try {
      final json = await _api.get('/api/v1/chat/invites/$token');
      return '${json['room_id']}';
    } on ApiException {
      return null;
    }
  }

  String _messageFor(ApiException e) {
    return switch (e.code) {
      'CHAT_008' => '유효하지 않은 초대 링크예요.',
      'CHAT_009' => '만료되었거나 취소된 초대 링크예요.',
      'CHAT_005' => '보관된 대화방이라 새로 들어갈 수 없어요.',
      'CHAT_006' => '대화방 정원이 가득 찼어요.',
      'CHAT_010' => '이 대화방에는 다시 들어갈 수 없어요.',
      _ => e.message,
    };
  }
}
