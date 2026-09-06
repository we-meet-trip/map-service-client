import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../common/theme/app_colors.dart';
import '../../../core/api/trip_api_service.dart';
import '../../../core/maps/map_adapter.dart';
import '../../../core/maps/map_bootstrap.dart';
import '../widgets/route_data_attribution.dart';

/// A day's actual stops and independently verified road legs, in supplied order.
/// Invalid stops stay in the sequence so removing one cannot join its neighbors.
class TripMapDayData {
  TripMapDayData(List<TripStop> allStops, this.day)
    : stops = List.unmodifiable(allStops.where((stop) => stop.day == day)) {
    for (var i = 0; i < stops.length; i++) {
      final stop = stops[i];
      if (_validPoint(stop.latitude, stop.longitude)) {
        markerPositions[i] = MapCoordinate(stop.latitude, stop.longitude);
      }
    }
    for (var i = 0; i < stops.length - 1; i++) {
      final transport = stops[i].transportToNext;
      if (!markerPositions.containsKey(i) ||
          !markerPositions.containsKey(i + 1) ||
          transport?.hasRoadRoute != true) {
        continue;
      }
      routes.add(
        MapPolylineOverlay(
          id: 'day_${day}_leg_$i',
          coords: transport!.path!
              .map((point) => MapCoordinate(point[0], point[1]))
              .toList(growable: false),
          color: AppColors.primaryScale[400],
          width: 5,
        ),
      );
    }
  }

  final int day;
  final List<TripStop> stops;
  final Map<int, MapCoordinate> markerPositions = {};
  final List<MapPolylineOverlay> routes = [];

  int get invalidStops => stops.length - markerPositions.length;
  int get unavailableLegs => math.max(0, stops.length - 1) - routes.length;

  MapCoordinateBounds? get bounds {
    final points = [
      ...markerPositions.values,
      for (final route in routes) ...route.coords,
    ];
    if (points.isEmpty) return null;
    return MapCoordinateBounds(
      southWest: MapCoordinate(
        points.map((p) => p.latitude).reduce(math.min),
        points.map((p) => p.longitude).reduce(math.min),
      ),
      northEast: MapCoordinate(
        points.map((p) => p.latitude).reduce(math.max),
        points.map((p) => p.longitude).reduce(math.max),
      ),
    );
  }

  static bool _validPoint(double lat, double lng) =>
      lat.isFinite && lng.isFinite && lat.abs() <= 90 && lng.abs() <= 180;
}

/// Fullscreen view of supplied itinerary data. AppMap owns the Google SDK,
/// readiness/error boundary, pointer gate and native controller lifecycle.
class GoogleMapScreen extends StatefulWidget {
  const GoogleMapScreen({
    super.key,
    this.stops = const [],
    this.showBackButton = false,
  });

  final List<TripStop> stops;
  final bool showBackButton;

  @override
  State<GoogleMapScreen> createState() => _GoogleMapScreenState();
}

class _GoogleMapScreenState extends State<GoogleMapScreen> {
  AppMapController? _controller;
  late List<int> _days;
  int _selectedDay = 1;
  int? _selectedStop;
  int _renderPass = 0;
  Future<void> _renderTail = Future.value();
  bool _overlayFailed = false;

  TripMapDayData get _data => TripMapDayData(widget.stops, _selectedDay);

  @override
  void initState() {
    super.initState();
    _updateDays();
    mapsReady.addListener(_mapReadinessChanged);
  }

  void _updateDays() {
    _days = widget.stops.map((s) => s.day).where((d) => d > 0).toSet().toList()
      ..sort();
    if (!_days.contains(_selectedDay)) {
      _selectedDay = _days.isEmpty ? 1 : _days.first;
    }
    _selectedStop = null;
    _overlayFailed = false;
  }

  @override
  void didUpdateWidget(GoogleMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-evaluate supplied data even when a caller reuses a mutable List.
    _updateDays();
    _queueRender();
  }

  void _mapReadinessChanged() {
    if (!mapsReady.value) {
      _renderPass++;
      _controller = null;
    }
  }

  @override
  void dispose() {
    mapsReady.removeListener(_mapReadinessChanged);
    _renderPass++;
    _controller = null;
    super.dispose();
  }

  void _selectDay(int day) {
    if (day == _selectedDay) return;
    setState(() {
      _selectedDay = day;
      _selectedStop = null;
      _overlayFailed = false;
    });
    _queueRender();
  }

  void _queueRender() {
    final pass = ++_renderPass;
    final controller = _controller;
    if (controller == null) return;
    final data = _data;
    // Serialize marker image capture and abandon any older day/controller pass.
    _renderTail = _renderTail.then((_) async {
      bool stale() =>
          !mounted || pass != _renderPass || controller != _controller;
      if (stale()) return;
      try {
        await controller.clearOverlays();
        if (stale()) return;
        for (final entry in data.markerPositions.entries) {
          if (!mounted || stale()) return;
          final icon = await MapOverlayImage.fromWidget(
            context: context,
            size: const Size(36, 36),
            widget: _numberMarker(entry.key + 1),
          );
          if (stale()) return;
          final marker = MapMarker(
            id: 'day_${data.day}_stop_${entry.key}',
            position: entry.value,
            icon: icon,
          );
          marker.setOnTapListener((_) {
            if (!stale()) setState(() => _selectedStop = entry.key);
          });
          await controller.addOverlay(marker);
          if (stale()) return;
        }
        for (final route in data.routes) {
          await controller.addOverlay(route);
          if (stale()) return;
        }
        final bounds = data.bounds;
        if (bounds != null) {
          await controller.updateCamera(
            MapCameraUpdate.fitBounds(
              bounds,
              padding: const EdgeInsets.all(44),
            ),
          );
        }
      } catch (_) {
        // The SDK or bitmap may disappear while a page/region is replaced.
        // Clear incomplete overlays and provide a retry, without raw locations.
        if (!stale()) {
          await controller.clearOverlays();
          if (!stale()) setState(() => _overlayFailed = true);
        }
      }
    });
  }

  Widget _numberMarker(int number) => Container(
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.primaryScale[400]!, width: 2),
    ),
    child: Text(
      '$number',
      style: TextStyle(
        color: AppColors.primaryScale[500],
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final bounds = data.bounds;
    return Scaffold(
      appBar: AppBar(
        title: const Text('여행 경로'),
        automaticallyImplyLeading: false,
        leading: widget.showBackButton
            ? BackButton(onPressed: () => Navigator.of(context).maybePop())
            : null,
      ),
      body: _days.isEmpty
          ? const Center(child: Text('표시할 일정이 없어요. 먼저 여행 일정을 선택해주세요.'))
          : Column(
              children: [
                if (_days.length > 1)
                  SizedBox(
                    height: 54,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final day in _days)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text('$day일차'),
                              selected: day == _selectedDay,
                              onSelected: (_) => _selectDay(day),
                            ),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: bounds == null
                      ? const Center(child: Text('이 날짜의 장소 좌표를 확인할 수 없어요.'))
                      : AppMap(
                          options: AppMapOptions(
                            initialCameraPosition: MapCameraPosition(
                              target: bounds.southWest,
                            ),
                            rotationGesturesEnable: false,
                          ),
                          onMapReady: (controller) {
                            _controller = controller;
                            _queueRender();
                          },
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_overlayFailed)
                          TextButton(
                            onPressed: () {
                              setState(() => _overlayFailed = false);
                              _queueRender();
                            },
                            child: const Text('경로 표시를 다시 시도하기'),
                          ),
                        if (data.unavailableLegs > 0)
                          const Text(
                            '일부 구간의 도로 경로를 확인하지 못했어요.',
                            style: TextStyle(fontSize: 12),
                          ),
                        if (data.invalidStops > 0)
                          const Text(
                            '좌표가 없는 장소는 지도에 표시할 수 없어요.',
                            style: TextStyle(fontSize: 12),
                          ),
                        SizedBox(
                          height: 44,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (var i = 0; i < data.stops.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ActionChip(
                                    label: Text(
                                      '${i + 1}. ${data.stops[i].name}',
                                    ),
                                    onPressed: () =>
                                        setState(() => _selectedStop = i),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_selectedStop != null &&
                            _selectedStop! < data.stops.length)
                          _stopDetail(data, _selectedStop!),
                        if (data.routes.isNotEmpty)
                          const RouteDataAttribution(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _stopDetail(TripMapDayData data, int index) {
    final stop = data.stops[index];
    final transport = index < data.stops.length - 1
        ? stop.transportToNext
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${stop.time} · ${stop.name}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (stop.address.isNotEmpty)
            Text(
              stop.address,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          if (transport != null)
            Text(
              '${transport.durationMinutes > 0 ? '약 ${transport.durationMinutes}분 · ' : ''}${transport.routeDescription}',
              style: const TextStyle(fontSize: 12),
            ),
        ],
      ),
    );
  }
}
