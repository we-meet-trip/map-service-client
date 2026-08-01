import 'package:flutter/foundation.dart';
import '../../../data/repositories/invite_repository.dart';

enum InviteStatus { idle, loading, success, alreadyJoined, error }

class InviteProvider extends ChangeNotifier {
  InviteProvider(this._repository);

  final InviteRepository _repository;

  String? pendingToken;
  InviteStatus status = InviteStatus.idle;
  String? resolvedChatRoomId;
  String? errorMessage;

  Future<void> resolveInvite(String token) async {
    status = InviteStatus.loading;
    notifyListeners();

    try {
      final result = await _repository.resolveInvite(token);
      if (result.success) {
        resolvedChatRoomId = result.chatRoomId;
        status =
            result.alreadyJoined ? InviteStatus.alreadyJoined : InviteStatus.success;
      } else {
        errorMessage = result.errorMessage ?? '유효하지 않은 링크입니다.';
        status = InviteStatus.error;
      }
    } catch (_) {
      errorMessage = '처리 중 오류가 발생했습니다.';
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
    errorMessage = null;
    notifyListeners();
  }
}
