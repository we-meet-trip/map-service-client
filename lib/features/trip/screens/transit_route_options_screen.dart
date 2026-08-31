import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/back_header.dart';
import '../../../common/widgets/app_loading_indicator.dart';
import '../../../core/api/transit_route_options_service.dart';
import 'subway_route_screen.dart' show SubwayRouteArgs;
import 'transit_route_map_screen.dart';

class TransitRouteOptionsScreen extends StatefulWidget {
  const TransitRouteOptionsScreen({
    super.key,
    required this.args,
    this.mode = TransitSearchMode.all,
  });

  final SubwayRouteArgs args;

  /// 어느 버튼으로 들어왔는지. 화면 제목과 빈 목록 문구가 이 값에 따라 다르다.
  final TransitSearchMode mode;

  @override
  State<TransitRouteOptionsScreen> createState() =>
      _TransitRouteOptionsScreenState();
}

class _TransitRouteOptionsScreenState
    extends State<TransitRouteOptionsScreen> {
  late Future<List<TransitRouteOption>> _future;

  @override
  void initState() {
    super.initState();
    _future = TransitRouteOptionsService.instance.findRouteOptions(
      startLng: widget.args.originLng,
      startLat: widget.args.originLat,
      endLng: widget.args.destinationLng,
      endLat: widget.args.destinationLat,
      mode: widget.mode,
    );
  }

  /// 버튼별 제목. 무엇을 눌러 들어왔는지 화면에서 다시 확인할 수 있게 한다.
  String get _title => switch (widget.mode) {
        TransitSearchMode.subway => '지하철 경로',
        TransitSearchMode.bus => '버스 경로',
        TransitSearchMode.all => '대중교통 경로',
      };

  /// 결과가 없을 때의 문구.
  ///
  /// 지하철은 노선이 아예 없는 지역에서 비는 일이 흔하다. 그때 "경로가 없다"고만
  /// 하면 갈 방법이 없는 것처럼 읽히므로, 버스로 갈 수 있다는 것을 함께 알린다.
  String get _emptyMessage => switch (widget.mode) {
        TransitSearchMode.subway =>
          '이 지역에는 지하철 노선이 없어요.\n버스로 가는 방법을 확인해보세요.',
        TransitSearchMode.bus => '버스로 갈 수 있는 경로가 없어요.',
        TransitSearchMode.all => '대중교통으로 갈 수 있는 경로가 없어요.',
      };

  void _onOptionTap(TransitRouteOption option) {
    context.push(
      '/saved/trip/directions/transit/map',
      extra: TransitRouteMapArgs(
        originLabel: widget.args.originLabel,
        originLat: widget.args.originLat,
        originLng: widget.args.originLng,
        destinationLabel: widget.args.destinationLabel,
        destinationLat: widget.args.destinationLat,
        destinationLng: widget.args.destinationLng,
        option: option,
      ),
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
            BackHeader(title: _title, onBack: () => context.pop()),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RouteEndpointLabel(
                      icon: Icons.trip_origin, label: widget.args.originLabel),
                  const SizedBox(height: 6),
                  _RouteEndpointLabel(
                      icon: Icons.place_rounded,
                      label: widget.args.destinationLabel),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<TransitRouteOption>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: AppLoadingIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        '경로를 불러오지 못했어요.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.neutralScale[400]),
                      ),
                    );
                  }
                  final options = snapshot.data ?? const [];
                  if (options.isEmpty) {
                    return Center(
                      child: Text(
                        _emptyMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.neutralScale[400],
                          height: 1.5,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: options.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) => _RouteOptionCard(
                      option: options[index],
                      onTap: () => _onOptionTap(options[index]),
                    ),
                  );
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

class _RouteOptionCard extends StatelessWidget {
  const _RouteOptionCard({required this.option, required this.onTap});

  final TransitRouteOption option;
  final VoidCallback onTap;

  static IconData _modeIcon(TransitLegType type) => switch (type) {
        TransitLegType.subway => Icons.directions_subway_filled_rounded,
        TransitLegType.bus => Icons.directions_bus_rounded,
        TransitLegType.walk => Icons.directions_walk_rounded,
      };

  static Color _modeColor(TransitLegType type) => switch (type) {
        TransitLegType.subway => AppColors.secondaryScale[500]!,
        TransitLegType.bus => AppColors.blueScale[500]!,
        TransitLegType.walk => AppColors.neutralScale[300]!,
      };

  static String _modeLabel(TransitLegType type) => switch (type) {
        TransitLegType.subway => '지하철',
        TransitLegType.bus => '버스',
        TransitLegType.walk => '도보',
      };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < option.modes.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(Icons.chevron_right_rounded,
                          size: 14, color: AppColors.neutralScale[300]),
                    ),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _modeColor(option.modes[i]).withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(_modeIcon(option.modes[i]),
                        size: 16, color: _modeColor(option.modes[i])),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${option.totalTimeMinutes}분',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.neutralScale[600],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${option.fare}원',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.tabBarUnselected,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.modes.map(_modeLabel).join(' · '),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.tabBarUnselected,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '환승 ${option.transferCount}회 · 도보 ${option.totalWalkMeters}m',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.tabBarUnselected,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.neutralScale[300]),
          ],
        ),
      ),
    );
  }
}
