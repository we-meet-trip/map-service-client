import '../../core/api/invite_api_service.dart';
import 'invite_link_repository.dart';

/// 서버가 발급한 초대 링크를 그대로 전달하는 발급기.
///
/// 주소를 클라이언트에서 조립하지 않는 이유: 기준 주소는 서버 설정이고 앱 링크
/// 검증도 그 주소를 기준으로 걸려 있다. 양쪽에서 따로 만들면 배포처가 바뀔 때
/// 한쪽만 따라가서, 링크가 앱 대신 브라우저로 열리는 형태로 조용히 어긋난다.
class ApiInviteLinkRepository implements InviteLinkRepository {
  ApiInviteLinkRepository({InviteApiService? api})
      : _api = api ?? InviteApiService.instance;

  final InviteApiService _api;

  @override
  Future<InviteLink> generateInviteLink(int roomId) async {
    final issued = await _api.generate(roomId);
    return InviteLink(url: issued.url, expiresAt: issued.expiresAt);
  }
}
