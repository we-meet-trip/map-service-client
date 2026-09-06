import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/app_loading_screen.dart';
import '../../../common/widgets/prev_button.dart';
import '../../../core/api/schedule_api_service.dart';
import '../../../core/api/trip_api_service.dart';
import '../../../core/state/trip_repository.dart';
import 'manual_plan_screen.dart';
import '../utils/plan_edit_draft.dart';

/// 저장된 일정을 직접 고치는 자리.
///
/// 고쳐서 동선을 만들면 그 결과로 저장된 일정을 갈아 끼운다. 저장을 다시
/// 누르게 하지 않는 이유는, 이미 저장한 일정을 손보는 흐름이라 사용자가
/// 기대하는 것이 "고침"이지 "새 일정"이 아니기 때문이다.
class SavedPlanEditScreen extends StatefulWidget {
  const SavedPlanEditScreen({
    super.key,
    required this.trip,
    this.route,
    this.revise,
  });

  final SavedTrip? trip;
  final Future<TripGenerateResponse> Function(TripRouteRequest)? route;
  final Future<ScheduleDetail> Function(int, String, String)? revise;

  @override
  State<SavedPlanEditScreen> createState() => _SavedPlanEditScreenState();
}

class _SavedPlanEditScreenState extends State<SavedPlanEditScreen> {
  Future<void>? _saveFuture;
  PlanEditDraft? _draft;

  @override
  void initState() {
    super.initState();
    final trip = widget.trip;
    if (trip != null) {
      _draft = PlanEditDraft(
        stops: trip.stops,
        transport: trip.transport ?? 'walk',
      );
    }
  }

  void _onRouted(TripGenerateResponse response) {
    final scheduleId = widget.trip?.scheduleId;
    if (scheduleId == null) return;
    setState(() {
      final revise =
          widget.revise ??
          ((int id, String jobId, String transport) => ScheduleApiService
              .instance
              .revise(scheduleId: id, jobId: jobId, transport: transport));
      _saveFuture = revise(scheduleId, response.tripId, _draft!.transport).then(
        (detail) {
          // 목록과 상세가 같은 일정을 보도록 갱신본으로 바꿔 둔다.
          TripRepository.instance.plannedTrips.value = [
            for (final t in TripRepository.instance.plannedTrips.value)
              if (t.scheduleId == scheduleId)
                SavedTrip.fromDetail(detail)
              else
                t,
          ];
        },
      );
      _saveFuture!.ignore();
    });
  }

  void _onSaved() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('일정을 고쳤어요.')));
    context.go('/saved');
  }

  void _onSaveError(Object error) {
    final message = error is TripApiException
        ? error.message
        : '고친 일정을 저장하지 못했어요. 잠시 후 다시 시도해주세요.';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _saveFuture = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    if (trip == null || !trip.canEdit || trip.stops.isEmpty) {
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
      draft: _draft,
      route: widget.route,
      initialStops: trip.stops,
      startDate: trip.tripStartDate,
      endDate: trip.tripEndDate,
      activeStartHour: trip.activeStartHour ?? 9,
      activeEndHour: trip.activeEndHour ?? 21,
      transport: trip.transport ?? 'walk',
      province: trip.province!,
      city: trip.city!,
      onRouted: _onRouted,
      onCancel: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/saved');
        }
      },
    );
  }

  Widget _buildBlocked() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.tune_rounded, size: 48, color: AppColors.neutralScale[200]),
        const SizedBox(height: 16),
        Text(
          '고칠 일정을 찾지 못했어요.\n저장한 일정에서 다시 열어주세요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.neutralScale[400],
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        PrevButton(onPressed: () => context.go('/saved'), label: '저장한 일정으로'),
      ],
    ),
  );
}
