import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../core/state/trip_repository.dart';
import '../invite/providers/invite_provider.dart';

/// 로그인이 끝난 뒤 갈 곳을 정한다.
///
/// 로그인은 대개 무언가를 하려다 막혀서 하게 된다. 그 무언가로 돌려보내지
/// 않으면 사용자는 처음부터 다시 시작해야 한다. 초대 링크가 특히 그렇다 —
/// 링크를 눌러 들어온 사람을 홈으로 보내면 초대는 그 자리에서 끊긴다.
///
/// 우선순위를 이 한 곳에 두는 이유: 로그인이 끝나는 화면이 셋(이메일 로그인,
/// 가입 완료, 카카오 뒤의 관심사 선택)인데, 각자 판단하면 어디로 보내는지가
/// 갈린다. 실제로 초대 토큰을 들고 있어도 홈으로 가 버리는 일이 있었다.
///
/// 대기 중인 초대 토큰은 여기서 꺼내 쓰고 지운다. 남겨 두면 다음 로그인 때
/// 엉뚱하게 그 방으로 끌려간다.
String postLoginRoute(BuildContext context) {
  final invite = context.read<InviteProvider>();
  final token = invite.pendingToken;
  if (token != null && token.isNotEmpty) {
    invite.pendingToken = null;
    return '/invite/$token';
  }
  if (TripRepository.instance.pendingTrip != null) {
    return '/trip';
  }
  return '/';
}
