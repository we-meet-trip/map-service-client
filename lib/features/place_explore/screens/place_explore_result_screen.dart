import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/app_loading_screen.dart';
import '../../../common/widgets/prev_button.dart';
import '../../../core/api/trip_api_service.dart';
import '../../../core/state/trip_repository.dart';
import '../../trip/screens/trip_created_screen.dart';
import '../utils/explore_route_request.dart';

/// 탐색에서 고른 장소를 남기고 일정을 다시 만들어 보여 준다.
///
/// 두 갈래다. 하나도 빼지 않았으면 같은 장소로 동선만 다시 짠다. 일부를
/// 뺐으면 남긴 장소는 그대로 두고 뺀 자리를 새 장소로 채워 달라고 한다 —
/// 마음에 든 곳은 지키고 나머지만 바꾸는 것이 이 화면의 뜻이기 때문이다.
///
/// 어느 쪽이든 방문 순서와 이동 구간은 서버가 다시 짜서 돌려주고, 그것을
/// 일정 화면에 그대로 넘긴다.
class PlaceExploreResultScreen extends StatefulWidget {
  const PlaceExploreResultScreen({super.key, required this.selectedIds});

  final Set<String> selectedIds;

  @override
  State<PlaceExploreResultScreen> createState() =>
      _PlaceExploreResultScreenState();
}

class _PlaceExploreResultScreenState extends State<PlaceExploreResultScreen> {
  late final TripPlanContext? _plan;
  late final ExploreRouteBlock? _blockedBy;

  /// 새 장소를 받아 오는 요청인지. 실패 안내 문구가 갈린다.
  bool _isResearch = false;

  Future<void>? _routeFuture;
  TripGenerateResponse? _result;

  @override
  void initState() {
    super.initState();
    final plan = TripRepository.instance.lastPlan;
    _plan = plan;

    // 하나라도 뺐고 재탐색을 걸 수 있는 맥락이면 뺀 자리를 새로 채운다.
    // 조건(예산·테마)이나 이전 추천 식별자가 없는 맥락 — 동선만 다시 만든
    // 일정이 그렇다 — 에서는 물어볼 근거가 없어 예전처럼 동선만 다시 짠다.
    final dropped = plan != null &&
        resolvePlanIndexes(plan, widget.selectedIds).length < plan.stops.length;
    if (dropped && plan.canResearch) {
      final draft = buildExploreResearchDraft(
        plan: plan,
        selectedIds: widget.selectedIds,
      );
      _blockedBy = draft.blockedBy;
      final request = draft.request;
      if (request != null) {
        _isResearch = true;
        _routeFuture = TripApiService.instance
            .researchTrip(request)
            .then((response) => _result = response);
      }
      return;
    }

    final draft = buildExploreRouteDraft(
      plan: plan,
      selectedIds: widget.selectedIds,
    );
    _blockedBy = draft.blockedBy;
    final request = draft.request;
    if (request != null) {
      _routeFuture = TripApiService.instance
          .routeTrip(request)
          .then((response) => _result = response);
    }
  }

  void _onLoadComplete() {
    final result = _result;
    final plan = _plan;
    if (result == null || result.stops.isEmpty) {
      // 장소가 하나도 없는 일정은 그릴 수 없다. 실패와 같이 다룬다.
      _onLoadError(const _EmptyRouteError());
      return;
    }
    if (plan != null) {
      // 다시 만든 일정이 이후 재탐색의 출발점이 되도록 조건을 갱신해 둔다.
      TripRepository.instance.setLastPlan(TripPlanContext(
        startDate: plan.startDate,
        endDate: plan.endDate,
        activeStartHour: plan.activeStartHour,
        activeEndHour: plan.activeEndHour,
        transport: plan.transport,
        province: plan.province,
        city: plan.city,
        stops: result.stops,
        // 식별자는 방금 만든 일정의 것으로 바꾸고 조건은 그대로 물려준다.
        // 이 값이 끊기면 다음 재탐색이 "무엇 말고"를 가리키지 못한다.
        tripId: result.tripId,
        minBudget: plan.minBudget,
        maxBudget: plan.maxBudget,
        themes: plan.themes,
      ));
    }
    setState(() => _routeFuture = null);
  }

  /// 실패하면 장소를 고르던 자리로 돌려보낸다. 고른 것이 그대로 남아 있어
  /// 바로 다시 시도할 수 있다.
  void _onLoadError(Object error) {
    final message = error is TripApiException
        ? error.message
        : _isResearch
            ? '새로운 장소를 받아오지 못했어요. 잠시 후 다시 시도해주세요.'
            : '동선을 다시 만들지 못했어요. 잠시 후 다시 시도해주세요.';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      context.go('/trip/place-explore/step2');
    });
  }

  @override
  Widget build(BuildContext context) {
    final blockedBy = _blockedBy;
    if (blockedBy != null) {
      return _buildBlocked(blockedBy);
    }

    final result = _result;
    if (result == null || _routeFuture != null) {
      return AppLoadingScreen(
        future: _routeFuture,
        minDuration: const Duration(seconds: 2),
        onComplete: _onLoadComplete,
        onError: _onLoadError,
      );
    }

    return TripCreatedScreen(
      response: result,
      startDate: _plan?.startDate,
      endDate: _plan?.endDate,
    );
  }

  Widget _buildBlocked(ExploreRouteBlock blockedBy) {
    final (message, label, destination) = switch (blockedBy) {
      ExploreRouteBlock.noPlan => (
          '고른 장소를 찾지 못했어요.\n일정을 먼저 만들어 주세요.',
          '← 여행 계획으로',
          '/trip',
        ),
      ExploreRouteBlock.tooFew => (
          '장소를 3곳 이상 골라 주세요.',
          '← 장소 고르러 가기',
          '/trip/place-explore/step2',
        ),
      ExploreRouteBlock.tooMany => (
          '한 번에 10곳까지만 동선을 만들 수 있어요.\n고른 장소를 줄여 주세요.',
          '← 장소 고르러 가기',
          '/trip/place-explore/step2',
        ),
    };

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.place_outlined,
              size: 48, color: AppColors.neutralScale[200]),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, color: AppColors.neutralScale[400], height: 1.5),
          ),
          const SizedBox(height: 24),
          PrevButton(
            onPressed: () => context.go(destination),
            label: label,
          ),
        ],
      ),
    );
  }
}

/// 장소가 비어 돌아온 응답. 사용자에게는 일반 실패와 같게 보인다.
class _EmptyRouteError implements Exception {
  const _EmptyRouteError();
}
