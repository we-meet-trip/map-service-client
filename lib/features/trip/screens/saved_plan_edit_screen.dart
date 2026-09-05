import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/app_loading_screen.dart';
import '../../../common/widgets/prev_button.dart';
import '../../../core/api/schedule_api_service.dart';
import '../../../core/api/trip_api_service.dart';
import '../../../core/state/trip_repository.dart';
import 'manual_plan_screen.dart';

/// 저장된 일정을 직접 고치는 자리.
///
/// 고쳐서 동선을 만들면 그 결과로 저장된 일정을 갈아 끼운다. 저장을 다시
/// 누르게 하지 않는 이유는, 이미 저장한 일정을 손보는 흐름이라 사용자가
/// 기대하는 것이 "고침"이지 "새 일정"이 아니기 때문이다.
class SavedPlanEditScreen extends StatefulWidget {
  const SavedPlanEditScreen({super.key, required this.trip});

  final SavedTrip trip;

  @override
  State<SavedPlanEditScreen> createState() => _SavedPlanEditScreenState();
}

class _SavedPlanEditScreenState extends State<SavedPlanEditScreen> {
  Future<void>? _saveFuture;

  void _onRouted(TripGenerateResponse response) {
    final scheduleId = widget.trip.scheduleId;
    if (scheduleId == null) return;
    setState(() {
      _saveFuture = ScheduleApiService.instance
          .revise(scheduleId: scheduleId, jobId: response.tripId)
          .then((detail) {
        // 목록과 상세가 같은 일정을 보도록 갱신본으로 바꿔 둔다.
        TripRepository.instance.plannedTrips.value = [
          for (final t in TripRepository.instance.plannedTrips.value)
            if (t.scheduleId == scheduleId) SavedTrip.fromDetail(detail) else t,
        ];
      });
    });
  }

  void _onSaved() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('일정을 고쳤어요.')));
    context.go('/saved');
  }

  void _onSaveError(Object error) {
    final message = error is TripApiException
        ? error.message
        : '고친 일정을 저장하지 못했어요. 잠시 후 다시 시도해주세요.';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _saveFuture = null);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    if (!trip.canEdit || trip.stops.isEmpty) {
      return _buildBlocked();
    }

    if (_saveFuture != null) {
      return AppLoadingScreen(
        future: _saveFuture,
        onComplete: _onSaved,
        onError: _onSaveError,
      );
    }

    return ManualPlanScreen(
      initialStops: trip.stops,
      startDate: trip.tripStartDate,
      endDate: trip.tripEndDate,
      activeStartHour: trip.activeStartHour ?? 9,
      activeEndHour: trip.activeEndHour ?? 21,
      transport: trip.transport ?? 'walk',
      province: trip.province!,
      city: trip.city!,
      onRouted: _onRouted,
      onCancel: () => context.pop(),
    );
  }

  Widget _buildBlocked() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tune_rounded,
                size: 48, color: AppColors.neutralScale[200]),
            const SizedBox(height: 16),
            Text(
              '이 일정은 고칠 수 없어요.\n지역 정보가 없는 예전 일정이에요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: AppColors.neutralScale[400],
                  height: 1.5),
            ),
            const SizedBox(height: 24),
            PrevButton(onPressed: () => context.pop(), label: '← 돌아가기'),
          ],
        ),
      );
}
