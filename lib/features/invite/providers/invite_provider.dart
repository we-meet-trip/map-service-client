import 'package:flutter/foundation.dart';

import '../../../data/repositories/invite_repository.dart';

/// 초대 링크를 눌렀을 때 화면이 놓일 수 있는 자리.
///
/// [loginRequired] 는 오류가 아니라 순서다. 링크를 받은 사람은 아직 계정이
/// 없을 수 있고, 로그인만 하면 그대로 이어진다.
enum InviteStatus { idle, loading, preview, loginRequired, success, alreadyJoined, error }

class InviteProvider extends ChangeNotifier {
  InviteProvider(this._repository);

  final InviteRepository _repository;

  /// 로그인 전에 눌린 링크. 로그인이 끝나면 이 값으로 이어서 처리한다.
  String? pendingToken;

  InviteStatus status = InviteStatus.idle;
  int? resolvedChatRoomId;
  String? roomTitle;
  int? participantCount;
  DateTime? expiresAt;
  String? errorMessage;

  /// 링크가 가리키는 방을 확인만 한다. 로그인 없이도 된다.
  ///
  /// 참가에 앞서 이걸 먼저 부르는 이유가 하나 더 있다. 이미 들어가 있는
  /// 사람에게 서버가 주는 거절 응답에는 방 번호가 없어서, 여기서 받아 둔
  /// 번호가 없으면 "이미 들어가 있으니 그 방으로 가라"를 만들 수 없다.
  Future<bool> loadPreview(String token) async {
    status = InviteStatus.loading;
    notifyListeners();

    final result = await _repository.preview(token);
    resolvedChatRoomId = result.chatRoomId;
    roomTitle = result.roomTitle;
    participantCount = result.participantCount;
    expiresAt = result.expiresAt;

    if (result.chatRoomId == null) {
      errorMessage = result.errorMessage ?? '유효하지 않은 링크예요.';
      status = InviteStatus.error;
      notifyListeners();
      return false;
    }

    // 방을 찾았으면 들어갈 수 없는 링크라도 무엇에 초대받았는지는 보여 준다.
    status = InviteStatus.preview;
    errorMessage = result.success ? null : result.errorMessage;
    notifyListeners();
    return result.success;
  }

  /// 링크로 방에 들어간다.
  Future<void> join(String token) async {
    status = InviteStatus.loading;
    notifyListeners();

    final result = await _repository.join(token);
    if (result.success) {
      resolvedChatRoomId = result.chatRoomId ?? resolvedChatRoomId;
      roomTitle = result.roomTitle ?? roomTitle;
      status = result.alreadyJoined ? InviteStatus.alreadyJoined : InviteStatus.success;
    } else if (result.loginRequired) {
      pendingToken = token;
      status = InviteStatus.loginRequired;
    } else {
      errorMessage = result.errorMessage ?? '유효하지 않은 링크예요.';
      status = InviteStatus.error;
    }
    notifyListeners();
  }

  void setError(String message) {
    errorMessage = message;
    status = InviteStatus.error;
    notifyListeners();
  }

  void reset() {
    status = InviteStatus.idle;
    resolvedChatRoomId = null;
    roomTitle = null;
    participantCount = null;
    expiresAt = null;
    errorMessage = null;
    notifyListeners();
  }
}
