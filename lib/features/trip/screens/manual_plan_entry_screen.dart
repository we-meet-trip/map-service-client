import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/prev_button.dart';
import '../../../core/api/trip_api_service.dart';
import '../../../core/state/trip_repository.dart';
import 'manual_plan_screen.dart';
import 'trip_created_screen.dart';

/// 저장 전 일정을 직접 고치는 자리.
///
/// 방금 만든 일정을 출발점으로 삼는다. 빈 상태에서 시작하려는 것이 아니라
/// "이 일정을 손보겠다"는 흐름이라, 조건(기간·이동수단·지역)도 그 일정의
/// 것을 그대로 쓴다.
///
/// 고쳐서 동선을 만들면 결과 화면으로 넘어가고, 거기서 여느 일정과 똑같이
/// 저장할 수 있다.
class ManualPlanEntryScreen extends StatefulWidget {
  const ManualPlanEntryScreen({super.key});

  @override
  State<ManualPlanEntryScreen> createState() => _ManualPlanEntryScreenState();
}

class _ManualPlanEntryScreenState extends State<ManualPlanEntryScreen> {
  late final TripPlanContext? _plan;
  TripGenerateResponse? _result;

  @override
  void initState() {
    super.initState();
    _plan = TripRepository.instance.lastPlan;
  }

  void _onRouted(TripGenerateResponse response) {
    final plan = _plan;
    if (plan != null) {
      // 고친 일정이 이후 흐름의 출발점이 된다. 조건은 그대로 물려준다.
      TripRepository.instance.setLastPlan(TripPlanContext(
        startDate: plan.startDate,
        endDate: plan.endDate,
        activeStartHour: plan.activeStartHour,
        activeEndHour: plan.activeEndHour,
        transport: plan.transport,
        province: plan.province,
        city: plan.city,
        stops: response.stops,
        tripId: response.tripId,
        minBudget: plan.minBudget,
        maxBudget: plan.maxBudget,
        themes: plan.themes,
      ));
    }
    setState(() => _result = response);
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    if (plan == null || plan.stops.isEmpty) {
      return _buildBlocked();
    }

    final result = _result;
    if (result != null) {
      return TripCreatedScreen(
        response: result,
        startDate: plan.startDate,
        endDate: plan.endDate,
      );
    }

    return ManualPlanScreen(
      initialStops: plan.stops,
      startDate: plan.startDate,
      endDate: plan.endDate,
      activeStartHour: plan.activeStartHour,
      activeEndHour: plan.activeEndHour,
      transport: plan.transport,
      province: plan.province,
      city: plan.city,
      onRouted: _onRouted,
      onCancel: () => context.go('/trip/search'),
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
              '고칠 일정을 찾지 못했어요.\n일정을 먼저 만들어 주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: AppColors.neutralScale[400],
                  height: 1.5),
            ),
            const SizedBox(height: 24),
            PrevButton(
              onPressed: () => context.go('/trip'),
              label: '← 여행 계획으로',
            ),
          ],
        ),
      );
}
