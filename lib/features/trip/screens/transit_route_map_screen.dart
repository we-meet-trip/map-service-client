import 'dart:math' show min, max;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/back_header.dart';
import '../../../core/api/transit_route_options_service.dart';
import '../../../core/naver_map/naver_map_adapter.dart';

class TransitRouteMapArgs {
  final String originLabel;
  final double originLat;
  final double originLng;
  final String destinationLabel;
  final double destinationLat;
  final double destinationLng;
  final TransitRouteOption option;

  const TransitRouteMapArgs({
    required this.originLabel,
    required this.originLat,
    required this.originLng,
    required this.destinationLabel,
    required this.destinationLat,
    required this.destinationLng,
    required this.option,
  });
}

class TransitRouteMapScreen extends StatefulWidget {
  const TransitRouteMapScreen({super.key, required this.args});

  final TransitRouteMapArgs args;

  @override
  State<TransitRouteMapScreen> createState() => _TransitRouteMapScreenState();
}

class _TransitRouteMapScreenState extends State<TransitRouteMapScreen> {
  static Color _legColor(TransitLegType type) => switch (type) {
        TransitLegType.subway => AppColors.secondaryScale[500]!,
        TransitLegType.bus => AppColors.blueScale[500]!,
        TransitLegType.walk => AppColors.neutralScale[300]!,
      };

  Future<void> _onMapReady(NaverMapController controller) async {
    await controller.clearOverlays();

    final args = widget.args;
    final legs = args.option.legs;
    final points = <NLatLng>[NLatLng(args.originLat, args.originLng)];
    NLatLng cursor = points.first;

    for (var i = 0; i < legs.length; i++) {
      final leg = legs[i];
      if (leg.geometry.isEmpty) continue; // 좌표 없는 도보 연결 구간
      final legCoords =
          leg.geometry.map((p) => NLatLng(p[0], p[1])).toList();

      // 이전 구간 끝(또는 출발지)과 이 구간 시작 사이는 좌표가 없어 잇는
      // 회색 연결선이다 — 실제 도보 경로가 아니라 근사 직선이다.
      await controller.addOverlay(NPathOverlay(
        id: 'connector_$i',
        coords: [cursor, legCoords.first],
        color: AppColors.neutralScale[300]!,
        width: 3,
      ));
      await controller.addOverlay(NPathOverlay(
        id: 'leg_$i',
        coords: legCoords,
        color: _legColor(leg.type),
        width: 6,
        outlineColor: Colors.white,
        outlineWidth: 2,
      ));
      cursor = legCoords.last;
      points.addAll(legCoords);
    }

    final destination = NLatLng(args.destinationLat, args.destinationLng);
    await controller.addOverlay(NPathOverlay(
      id: 'connector_end',
      coords: [cursor, destination],
      color: AppColors.neutralScale[300]!,
      width: 3,
    ));
    points.add(destination);

    await controller.addOverlay(
      NMarker(id: 'origin', position: points.first),
    );
    await controller.addOverlay(
      NMarker(id: 'destination', position: destination),
    );

    final lats = points.map((p) => p.latitude);
    final lngs = points.map((p) => p.longitude);
    final bounds = NLatLngBounds(
      southWest: NLatLng(lats.reduce(min), lngs.reduce(min)),
      northEast: NLatLng(lats.reduce(max), lngs.reduce(max)),
    );
    await controller.updateCamera(
      NCameraUpdate.fitBounds(bounds, padding: const EdgeInsets.all(56))
        ..setAnimation(
          animation: NCameraAnimation.fly,
          duration: const Duration(milliseconds: 800),
        ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final option = widget.args.option;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BackHeader(title: '경로 지도', onBack: () => context.pop()),
            SizedBox(
              width: double.infinity,
              height: 280,
              child: NaverMap(
                options: NaverMapViewOptions(
                  initialCameraPosition: NCameraPosition(
                    target:
                        NLatLng(widget.args.originLat, widget.args.originLng),
                    zoom: 13,
                  ),
                  scrollGesturesEnable: true,
                  zoomGesturesEnable: true,
                  rotationGesturesEnable: false,
                  mapType: NMapType.basic,
                ),
                onMapReady: _onMapReady,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
                        _SummaryStat(
                            label: '소요시간', value: '${option.totalTimeMinutes}분'),
                        _SummaryStat(
                            label: '환승', value: '${option.transferCount}회'),
                        _SummaryStat(label: '요금', value: '${option.fare}원'),
                        _SummaryStat(
                            label: '도보', value: '${option.totalWalkMeters}m'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (var i = 0; i < option.legs.length; i++)
                    _LegTile(
                        leg: option.legs[i], isLast: i == option.legs.length - 1),
                ],
              ),
            ),
          ],
        ),
      ),
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

class _LegTile extends StatelessWidget {
  const _LegTile({required this.leg, required this.isLast});

  final TransitRouteLeg leg;
  final bool isLast;

  IconData get _icon => switch (leg.type) {
        TransitLegType.subway => Icons.directions_subway_filled_rounded,
        TransitLegType.bus => Icons.directions_bus_rounded,
        TransitLegType.walk => Icons.directions_walk_rounded,
      };

  Color get _iconColor => switch (leg.type) {
        TransitLegType.subway => AppColors.secondaryScale[500]!,
        TransitLegType.bus => AppColors.blueScale[500]!,
        TransitLegType.walk => AppColors.neutralScale[300]!,
      };

  String get _title {
    if (leg.type == TransitLegType.walk) return '도보 이동';
    final line = leg.lineName ?? '';
    final stationInfo = leg.stationCount != null ? ' (${leg.stationCount}개 역)' : '';
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
                    '${leg.startName} → ${leg.endName} · ${leg.sectionTimeMinutes}분',
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
