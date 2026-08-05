import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../common/widgets/app_loading_indicator.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/schedule_api_service.dart';
import '../../../core/state/trip_repository.dart';

/// 저장된 일정을 열어 결과 화면으로 넘긴다.
///
/// 목록에는 제목과 기간만 있어 화면을 그릴 수 없다. 방문지와 도로 경로는
/// 상세 조회로만 오고, 서버가 조회 시점 기준으로 경로를 다시 얹는다.
/// 조립에 시간이 걸려 진행 표시를 덮어 둔다.
///
/// 진행 표시는 **이 화면이 속한 탭 안쪽 네비게이터**에 띄우고 같은 곳에서
/// 닫는다. 띄운 곳과 닫는 곳이 어긋나면 닫기 요청이 진행 표시가 아니라 탭
/// 안쪽 페이지를 뽑아 버린다. 그러면 진행 표시는 화면에 그대로 남고, 탭해서
/// 닫을 수도 없어 멈춘 것처럼 보인다.
Future<void> openSchedule(BuildContext context, int scheduleId) async {
  final navigator = Navigator.of(context, rootNavigator: false);
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: false,
    builder: (_) => const Center(child: AppLoadingIndicator()),
  );

  final ScheduleDetail detail;
  try {
    detail = await ScheduleApiService.instance.detail(scheduleId);
  } on ApiException catch (e) {
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return;
  } catch (_) {
    // 공통 계층이 서버 오류 형태로 바꿔 주는 것은 응답 지연 하나뿐이다. 연결이
    // 끊기거나 응답 형식이 어긋나면 다른 모양의 오류가 그대로 올라온다. 그것을
    // 여기서 받지 않으면 아래 닫는 줄에 닿지 못해 진행 표시가 남는다.
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('일정을 불러오지 못했어요. 잠시 후 다시 시도해주세요.')),
    );
    return;
  }

  navigator.pop();
  router.go('/saved/trip', extra: SavedTrip.fromDetail(detail));
}
