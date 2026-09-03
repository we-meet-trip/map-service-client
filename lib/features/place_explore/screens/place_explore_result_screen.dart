import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/app_loading_screen.dart';
import '../../../common/widgets/prev_button.dart';
import '../../../core/api/trip_api_service.dart';
import '../../../core/state/trip_repository.dart';
import '../../trip/screens/trip_created_screen.dart';
import '../utils/explore_route_request.dart';

/// 탐색에서 고른 장소로 동선을 다시 만들어 보여 준다.
///
/// 고른 장소만 정해졌을 뿐 방문 순서와 이동 구간은 아직 없다. 서버가 순서를
/// 다시 짜고 도로를 따라가는 경로를 붙여 돌려주면 그것을 일정 화면에 그대로
/// 넘긴다.
class PlaceExploreResultScreen extends StatefulWidget {
  const PlaceExploreResultScreen({super.key, required this.selectedIds});

  final Set<String> selectedIds;

  @override
  State<PlaceExploreResultScreen> createState() =>
      _PlaceExploreResultScreenState();
}

class _PlaceExploreResultScreenState extends State<PlaceExploreResultScreen> {
  late final TripPlanContext? _plan;
  late final ExploreRouteDraft _draft;

  Future<void>? _routeFuture;
  TripGenerateResponse? _result;

  @override
  void initState() {
    super.initState();
    _plan = TripRepository.instance.lastPlan;
    _draft = buildExploreRouteDraft(
      plan: _plan,
      selectedIds: widget.selectedIds,
    );
    final request = _draft.request;
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
      ));
    }
    setState(() => _routeFuture = null);
  }

  /// 실패하면 장소를 고르던 자리로 돌려보낸다. 고른 것이 그대로 남아 있어
  /// 바로 다시 시도할 수 있다.
  void _onLoadError(Object error) {
    final message = error is TripApiException
        ? error.message
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
    final blockedBy = _draft.blockedBy;
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
