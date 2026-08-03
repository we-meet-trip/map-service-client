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
Future<void> openSchedule(BuildContext context, int scheduleId) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: AppLoadingIndicator()),
  );
  try {
    final detail = await ScheduleApiService.instance.detail(scheduleId);
    navigator.pop();
    router.go('/saved/trip', extra: SavedTrip.fromDetail(detail));
  } on ApiException catch (e) {
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}
