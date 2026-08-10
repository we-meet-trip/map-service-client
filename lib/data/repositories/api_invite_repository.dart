import '../../core/api/api_client.dart';
import '../../core/api/invite_api_service.dart';
import 'invite_repository.dart';

/// 서버를 실제로 보는 초대 해석기.
///
/// 미리보기와 참가를 따로 두는 이유: 서버는 이미 들어가 있는 사람에게 409 를
/// 주는데 그 본문에는 방 번호가 없다. 그래서 참가만으로는 "이미 들어가 있으니
/// 그 방으로 가라"를 만들 수 없고, 먼저 확인해 둔 방 번호가 있어야 한다.
/// 미리보기가 로그인 없이 열려 있어 그 확인이 공짜라는 점도 함께 쓴다.
class ApiInviteRepository implements InviteRepository {
  ApiInviteRepository({InviteApiService? api})
      : _api = api ?? InviteApiService.instance;

  final InviteApiService _api;

  /// 미리보기에서 얻은 방 번호. 참가가 409 로 돌아왔을 때 쓰려고 남겨 둔다.
  final Map<String, int> _previewedRoomIds = {};

  @override
  Future<InviteResolveResult> preview(String token) async {
    try {
      final preview = await _api.preview(token);
      _previewedRoomIds[token] = preview.roomId;
      return InviteResolveResult(
        success: preview.joinable,
        alreadyJoined: false,
        chatRoomId: preview.roomId,
        roomTitle: preview.title,
        participantCount: preview.participantCount,
        expiresAt: preview.expiresAt,
        errorMessage: preview.joinable ? null : '지금은 참가할 수 없는 링크예요.',
      );
    } on ApiException catch (e) {
      return _failure(e);
    }
  }

  @override
  Future<InviteResolveResult> join(String token) async {
    try {
      final room = await _api.join(token);
      return InviteResolveResult(
        success: true,
        alreadyJoined: false,
        chatRoomId: room.roomId,
        roomTitle: room.title,
        participantCount: room.participantCount,
        expiresAt: room.expiresAt,
      );
    } on ApiException catch (e) {
      // 이미 들어가 있다는 것은 실패가 아니다. 미리 확인해 둔 방으로 보낸다.
      if (e.code == 'CHAT_007') {
        final roomId = _previewedRoomIds[token];
        if (roomId != null) {
          return InviteResolveResult(
            success: true,
            alreadyJoined: true,
            chatRoomId: roomId,
          );
        }
      }
      return _failure(e);
    }
  }

  /// 서버가 준 코드를 사람이 읽을 문구로 옮긴다.
  ///
  /// 전부 한 문구로 뭉치면 링크가 죽은 것인지, 방이 찬 것인지, 로그인만 하면
  /// 되는 것인지 구분이 사라져 다음에 무엇을 해야 할지 알 수 없게 된다.
  InviteResolveResult _failure(ApiException e) {
    if (e.statusCode == 401) {
      return const InviteResolveResult(
        success: false,
        alreadyJoined: false,
        loginRequired: true,
      );
    }
    final message = switch (e.code) {
      'CHAT_008' => '유효하지 않은 초대 링크예요.',
      'CHAT_009' => '만료되었거나 취소된 초대 링크예요.',
      'CHAT_006' => '채팅방 정원이 가득 찼어요.',
      'CHAT_010' => '이 채팅방에는 다시 참가할 수 없어요.',
      'CHAT_005' => '이미 끝난 여행의 채팅방이에요.',
      'RATE_001' => '요청이 많아요. 잠시 후 다시 시도해주세요.',
      _ => e.message,
    };
    return InviteResolveResult(
      success: false,
      alreadyJoined: false,
      errorMessage: message,
    );
  }
}
