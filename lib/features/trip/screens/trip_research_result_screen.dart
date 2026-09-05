import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/app_loading_screen.dart';
import '../../../common/widgets/prev_button.dart';
import '../../../core/api/trip_api_service.dart';
import '../../../core/state/trip_repository.dart';
import 'trip_created_screen.dart';

/// 같은 조건으로 장소를 전부 새로 받아 온다.
///
/// 조건을 다시 묻지 않는다 — 사용자가 원한 것은 "조건을 바꾸겠다"가 아니라
/// "이 장소들 말고 다른 곳"이기 때문이다. 방금 본 일정의 조건을 그대로 다시
/// 싣고, 그 장소들은 제외 목록으로 보낸다.
class TripResearchResultScreen extends StatefulWidget {
  const TripResearchResultScreen({super.key});

  @override
  State<TripResearchResultScreen> createState() =>
      _TripResearchResultScreenState();
}

class _TripResearchResultScreenState extends State<TripResearchResultScreen> {
  late final TripPlanContext? _plan;

  Future<void>? _researchFuture;
  TripGenerateResponse? _result;

  @override
  void initState() {
    super.initState();
    final plan = TripRepository.instance.lastPlan;
    _plan = plan;
    if (plan == null || !plan.canResearch) return;

    _researchFuture = TripApiService.instance
        .researchTrip(TripResearchRequest(
          startDate: plan.startDate,
          endDate: plan.endDate,
          activeStartHour: plan.activeStartHour,
          activeEndHour: plan.activeEndHour,
          minBudget: plan.minBudget!,
          maxBudget: plan.maxBudget!,
          themes: plan.themes,
          transport: plan.transport,
          province: plan.province,
          city: plan.city,
          prevTripId: plan.tripId!,
          exclude: [
            for (final stop in plan.stops)
              if ((stop.contentId ?? '').isNotEmpty) stop.contentId!,
          ],
        ))
        .then((response) => _result = response);
  }

  void _onLoadComplete() {
    final result = _result;
    final plan = _plan;
    if (result == null || result.stops.isEmpty) {
      _onLoadError(const _EmptyResearchError());
      return;
    }
    if (plan != null) {
      // 이번 결과가 다음 재탐색의 출발점이 된다. 조건은 그대로 물려준다.
      TripRepository.instance.setLastPlan(TripPlanContext(
        startDate: plan.startDate,
        endDate: plan.endDate,
        activeStartHour: plan.activeStartHour,
        activeEndHour: plan.activeEndHour,
        transport: plan.transport,
        province: plan.province,
        city: plan.city,
        stops: result.stops,
        tripId: result.tripId,
        minBudget: plan.minBudget,
        maxBudget: plan.maxBudget,
        themes: plan.themes,
      ));
    }
    setState(() => _researchFuture = null);
  }

  /// 실패하면 고르던 자리로 돌려보낸다. 하루 한도를 넘긴 경우처럼 서버가
  /// 사유를 준 때는 그 문구를 그대로 보여 준다.
  void _onLoadError(Object error) {
    final message = error is TripApiException
        ? error.message
        : '새로운 일정을 받아오지 못했어요. 잠시 후 다시 시도해주세요.';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      context.go('/trip/search');
    });
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    if (plan == null || !plan.canResearch) {
      return _buildBlocked();
    }

    final result = _result;
    if (result == null || _researchFuture != null) {
      return AppLoadingScreen(
        future: _researchFuture,
        minDuration: const Duration(seconds: 2),
        onComplete: _onLoadComplete,
        onError: _onLoadError,
      );
    }

    return TripCreatedScreen(
      response: result,
      startDate: plan.startDate,
      endDate: plan.endDate,
    );
  }

  /// 다시 물어볼 일정이 없는 경우 — 화면을 건너뛰고 들어왔거나, 조건 없이
  /// 만들어진 일정만 남아 있는 경우다. 이때는 처음부터 만들게 한다.
  Widget _buildBlocked() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.refresh, size: 48, color: AppColors.neutralScale[200]),
          const SizedBox(height: 16),
          Text(
            '다시 추천할 일정을 찾지 못했어요.\n일정을 먼저 만들어 주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, color: AppColors.neutralScale[400], height: 1.5),
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
}

/// 장소가 비어 돌아온 응답. 사용자에게는 일반 실패와 같게 보인다.
class _EmptyResearchError implements Exception {
  const _EmptyResearchError();
}
