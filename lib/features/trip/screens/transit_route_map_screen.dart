import 'dart:math' show min, max;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/back_header.dart';
import '../../../core/api/transit_route_options_service.dart';
import '../../../core/maps/map_adapter.dart';
import '../widgets/route_data_attribution.dart';

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

/// 지도에 그릴 도보 연결선 하나. [id] 는 지도 오버레이 이름이다.
typedef TransitConnector = ({String id, MapCoordinate from, MapCoordinate to});

/// 구간 사이를 잇는 도보 연결선을 그리는 순서대로 뽑는다.
///
/// 출발지 → 첫 구간 시작, 구간 끝 → 다음 구간 시작(환승 걷기), 마지막 구간 끝 →
/// 도착지. 좌표가 없는 구간(순수 도보 연결)은 건너뛴다. 그리는 쪽과 보행 경로를
/// 조회하는 쪽이 이 한 함수를 같이 써서, 둘이 서로 다른 연결선을 보는 일이 없게
/// 한다.
List<TransitConnector> transitConnectors(
  MapCoordinate origin,
  MapCoordinate destination,
  List<TransitRouteLeg> legs,
) {
  final result = <TransitConnector>[];
  var cursor = origin;
  for (var i = 0; i < legs.length; i++) {
    final geometry = legs[i].geometry;
    if (geometry.isEmpty) continue;
    result.add((
      id: 'connector_$i',
      from: cursor,
      to: MapCoordinate(geometry.first[0], geometry.first[1]),
    ));
    cursor = MapCoordinate(geometry.last[0], geometry.last[1]);
  }
  result.add((id: 'connector_end', from: cursor, to: destination));
  return result;
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
        TransitLegType.express => AppColors.tealScale[300]!,
        TransitLegType.intercity => AppColors.tealScale[400]!,
        TransitLegType.walk => AppColors.neutralScale[300]!,
      };

  /// 이보다 짧은 연결선은 보행 경로를 부르지 않고 직선으로 둔다. 같은 역 안
  /// 환승처럼 짧은 걷기는 엔진이 역 밖으로 돌아가는 선을 낼 수 있다.
  /// 30m 는 짐작한 값이다 — 실제 경로로 확인한 뒤 조정한다.
  static const _minWalkPathMeters = 30.0;

  MapCoordinate get _origin =>
      MapCoordinate(widget.args.originLat, widget.args.originLng);
  MapCoordinate get _destination =>
      MapCoordinate(widget.args.destinationLat, widget.args.destinationLng);

  /// 지도가 준비되면 가진 좌표(정류장 직선)로 바로 그리고, 실제 노선 좌표와
  /// 도보 연결선의 보행 경로를 받는 대로 차례로 다시 그린다.
  ///
  /// 받을 때까지 기다렸다 한 번에 그리지 않는 이유: 둘 다 부가 정보라 서버가
  /// 늦거나 못 줘도 지도가 비어 있으면 안 된다. 못 받은 것은 직선이 그대로
  /// 남는다. 다시 그릴 때는 카메라를 맞추지 않는다 — 같은 경로라 범위가 거의
  /// 같고, 그사이 사용자가 지도를 움직였다면 그 위치를 빼앗게 된다.
  Future<void> _onMapReady(AppMapController controller) async {
    final option = widget.args.option;
    var legs = option.legs;
    await _drawRoute(controller, legs, fitCamera: true);

    final roadLegs =
        await TransitRouteOptionsService.instance.fetchLaneLegs(option);
    if (!mounted) return;
    if (roadLegs != null) {
      legs = roadLegs;
      await _drawRoute(controller, legs, fitCamera: false);
    }

    // 도보 연결선은 노선 좌표 조회가 끝난 뒤에 부른다 — 연결선 끝점이 지금
    // 그려진 구간 끝과 맞아야 한다.
    final connectors = transitConnectors(_origin, _destination, legs)
        .where((c) =>
            Geolocator.distanceBetween(c.from.latitude, c.from.longitude,
                c.to.latitude, c.to.longitude) >=
            _minWalkPathMeters)
        .toList();
    if (connectors.isEmpty) return;
    final paths = await TransitRouteOptionsService.instance.fetchWalkPaths([
      for (final c in connectors)
        ([c.from.latitude, c.from.longitude], [c.to.latitude, c.to.longitude]),
    ]);
    if (paths == null || !mounted) return;
    // 엔진 경로는 도로에 붙은 점에서 시작·끝나므로 양 끝을 원래 점에 잇는다.
    final walkPaths = <String, List<MapCoordinate>>{
      for (var i = 0; i < connectors.length; i++)
        if (paths[i] != null)
          connectors[i].id: [
            connectors[i].from,
            ...paths[i]!.map((p) => MapCoordinate(p[0], p[1])),
            connectors[i].to,
          ],
    };
    await _drawRoute(controller, legs, fitCamera: false, walkPaths: walkPaths);
  }

  /// [walkPaths] 는 연결선 id → 보행 경로. 없는 연결선은 회색 직선으로 그린다.
  Future<void> _drawRoute(
    AppMapController controller,
    List<TransitRouteLeg> legs, {
    required bool fitCamera,
    Map<String, List<MapCoordinate>> walkPaths = const {},
  }) async {
    await controller.clearOverlays();

    // 연결선을 먼저 그려 구간 선이 그 위에 오게 한다.
    for (final c in transitConnectors(_origin, _destination, legs)) {
      await controller.addOverlay(MapPathOverlay(
        id: c.id,
        coords: walkPaths[c.id] ?? [c.from, c.to],
        color: AppColors.neutralScale[300]!,
        width: 3,
      ));
    }

    final points = <MapCoordinate>[_origin];
    for (var i = 0; i < legs.length; i++) {
      final leg = legs[i];
      if (leg.geometry.isEmpty) continue; // 좌표 없는 도보 연결 구간
      final legCoords =
          leg.geometry.map((p) => MapCoordinate(p[0], p[1])).toList();
      await controller.addOverlay(MapPathOverlay(
        id: 'leg_$i',
        coords: legCoords,
        color: _legColor(leg.type),
        width: 6,
        outlineColor: Colors.white,
        outlineWidth: 2,
      ));
      points.addAll(legCoords);
    }

    final destination = _destination;
    points.add(destination);

    await controller.addOverlay(
      MapMarker(id: 'origin', position: points.first,
          icon: MapOverlayImage.defaultMarker(hue: 120)),
    );
    await controller.addOverlay(
      MapMarker(id: 'destination', position: destination,
          icon: MapOverlayImage.defaultMarker()),
    );

    if (!fitCamera) return;
    final lats = points.map((p) => p.latitude);
    final lngs = points.map((p) => p.longitude);
    final bounds = MapCoordinateBounds(
      southWest: MapCoordinate(lats.reduce(min), lngs.reduce(min)),
      northEast: MapCoordinate(lats.reduce(max), lngs.reduce(max)),
    );
    await controller.updateCamera(
      MapCameraUpdate.fitBounds(bounds, padding: const EdgeInsets.all(56))
        ..setAnimation(
          animation: MapCameraAnimation.fly,
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
              child: AppMap(
                options: AppMapOptions(
                  initialCameraPosition: MapCameraPosition(
                    target:
                        MapCoordinate(widget.args.originLat, widget.args.originLng),
                    zoom: 13,
                  ),
                  scrollGesturesEnable: true,
                  zoomGesturesEnable: true,
                  rotationGesturesEnable: false,
                  mapType: AppMapType.basic,
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
                  // 노선·시각의 발급처를 이 화면에서도 밝힌다.
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: RouteDataAttribution.transit(),
                  ),
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
        TransitLegType.express => Icons.directions_bus_filled_rounded,
        TransitLegType.intercity => Icons.airport_shuttle_rounded,
        TransitLegType.walk => Icons.directions_walk_rounded,
      };

  Color get _iconColor => switch (leg.type) {
        TransitLegType.subway => AppColors.secondaryScale[500]!,
        TransitLegType.bus => AppColors.blueScale[500]!,
        TransitLegType.express => AppColors.tealScale[300]!,
        TransitLegType.intercity => AppColors.tealScale[400]!,
        TransitLegType.walk => AppColors.neutralScale[300]!,
      };

  String get _title => leg.type == TransitLegType.walk ? '도보 이동' : (leg.lineName ?? '');

  String get _stopUnit => leg.type == TransitLegType.bus ? '개 정류장' : '개 역';

  void _showStops(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _StopListSheet(
        title: leg.lineName ?? _title,
        color: _iconColor,
        stopNames: leg.stopNames,
      ),
    );
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
                  Row(
                    children: [
                      Text(
                        _title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutralScale[600],
                        ),
                      ),
                      if (leg.stopNames.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _showStops(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _iconColor.withAlpha(24),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${leg.stopNames.length}$_stopUnit',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _iconColor,
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded,
                                    size: 13, color: _iconColor),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
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

class _StopListSheet extends StatelessWidget {
  const _StopListSheet({
    required this.title,
    required this.color,
    required this.stopNames,
  });

  final String title;
  final Color color;
  final List<String> stopNames;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.neutralScale[100],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '$title 경유 정류장',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.neutralScale[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${stopNames.length}개 정류장을 지나요',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.tabBarUnselected,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: stopNames.length,
                itemBuilder: (context, index) {
                  final isFirst = index == 0;
                  final isLast = index == stopNames.length - 1;
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            if (!isFirst)
                              Expanded(
                                child: Container(width: 2, color: color.withAlpha(60)),
                              ),
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            if (!isLast)
                              Expanded(
                                child: Container(width: 2, color: color.withAlpha(60)),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              stopNames[index],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    isFirst || isLast ? FontWeight.w700 : FontWeight.w500,
                                color: AppColors.neutralScale[600],
                              ),
                            ),
                          ),
                        ),
                      ],
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
