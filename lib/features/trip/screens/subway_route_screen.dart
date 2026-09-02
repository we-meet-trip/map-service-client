import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/back_header.dart';
import '../../../common/widgets/app_loading_indicator.dart';
import '../../../core/api/subway_route_service.dart';

class SubwayRouteArgs {
  final String originLabel;
  final double originLat;
  final double originLng;
  final String destinationLabel;
  final double destinationLat;
  final double destinationLng;

  const SubwayRouteArgs({
    required this.originLabel,
    required this.originLat,
    required this.originLng,
    required this.destinationLabel,
    required this.destinationLat,
    required this.destinationLng,
  });
}

class SubwayRouteScreen extends StatefulWidget {
  const SubwayRouteScreen({super.key, required this.args});

  final SubwayRouteArgs args;

  @override
  State<SubwayRouteScreen> createState() => _SubwayRouteScreenState();
}

class _SubwayRouteScreenState extends State<SubwayRouteScreen> {
  late Future<SubwayRouteResult> _future;

  @override
  void initState() {
    super.initState();
    _future = SubwayRouteService.instance.findFastestSubwayRoute(
      startLng: widget.args.originLng,
      startLat: widget.args.originLat,
      endLng: widget.args.destinationLng,
      endLat: widget.args.destinationLat,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BackHeader(title: '지하철 경로', onBack: () => context.pop()),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RouteEndpointLabel(icon: Icons.trip_origin, label: widget.args.originLabel),
                  const SizedBox(height: 6),
                  _RouteEndpointLabel(icon: Icons.place_rounded, label: widget.args.destinationLabel),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<SubwayRouteResult>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: AppLoadingIndicator());
                  }
                  final route = snapshot.data?.route;
                  if (snapshot.hasError || route == null) {
                    // 길이 없는 것과 물어보지 못한 것을 다른 문구로 알린다.
                    final message =
                        snapshot.data?.status == SubwayRouteStatus.notFound
                            ? '지하철만으로 갈 수 있는 경로가 없어요.'
                            : '지금은 지하철 경로를 불러올 수 없어요.';
                    return Center(
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.neutralScale[400]),
                      ),
                    );
                  }
                  return _SubwayRouteResult(route: route);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteEndpointLabel extends StatelessWidget {
  const _RouteEndpointLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.tripAccentPurple),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.neutralScale[600],
            ),
          ),
        ),
      ],
    );
  }
}

class _SubwayRouteResult extends StatelessWidget {
  const _SubwayRouteResult({required this.route});

  final SubwayRoute route;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.neutralScale[0],
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.secondaryScale[900]!.withAlpha(15),
                blurRadius: 10,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SummaryStat(label: '소요시간', value: '${route.totalTimeMinutes}분'),
              _SummaryStat(label: '환승', value: '${route.transferCount}회'),
              _SummaryStat(label: '요금', value: '${route.fare}원'),
              _SummaryStat(label: '도보', value: '${route.totalWalkMeters}m'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < route.steps.length; i++)
          _StepTile(step: route.steps[i], isLast: i == route.steps.length - 1),
      ],
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.tabBarUnselected,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.neutralScale[600],
          ),
        ),
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.step, required this.isLast});

  final SubwayRouteStep step;
  final bool isLast;

  IconData get _icon => switch (step.type) {
        SubwayStepType.subway => Icons.directions_subway_filled_rounded,
        SubwayStepType.bus => Icons.directions_bus_rounded,
        SubwayStepType.walk => Icons.directions_walk_rounded,
      };

  Color get _iconColor => switch (step.type) {
        SubwayStepType.subway => AppColors.secondaryScale[500]!,
        SubwayStepType.bus => AppColors.blueScale[500]!,
        SubwayStepType.walk => AppColors.neutralScale[300]!,
      };

  String get _title {
    if (step.type == SubwayStepType.walk) return '도보 이동';
    final line = step.lineName ?? '';
    final stationInfo = step.stationCount != null ? ' (${step.stationCount}개 역)' : '';
    return '$line$stationInfo';
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _iconColor.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(_icon, size: 18, color: _iconColor),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: AppColors.mypageDivider),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutralScale[600],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${step.startName} → ${step.endName} · ${step.sectionTimeMinutes}분',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.tabBarUnselected,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
