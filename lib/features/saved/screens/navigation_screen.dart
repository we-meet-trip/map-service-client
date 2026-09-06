import 'dart:async';
import 'dart:math' show min, max;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../common/theme/app_colors.dart';
import '../../../common/theme/app_icons.dart';
import '../../../core/api/schedule_api_service.dart';
import '../../../core/api/trip_api_service.dart';
import '../../../core/state/trip_repository.dart';
import '../../trip/widgets/transport_theme.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key, required this.trip});

  final SavedTrip trip;

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen>
    with SingleTickerProviderStateMixin {
  // ── 지도 ────────────────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  Set<Marker> _markers = const {};
  Set<Polyline> _polylines = const {};

  /// onCameraMove 로 갱신되는 현재 카메라 위치 (_resetNorth 에서 사용)
  CameraPosition? _currentCameraPosition;

  /// 폰 나침반 센서 방위각 (도 단위, 0=북, 시계방향 증가)
  double _deviceHeading = 0.0;

  /// 사용자 이동 방향 (GPS heading, 카메라 재센터링용)
  double _userHeading = 0.0;

  /// 카메라 베어링 부드러운 보간용 (low-pass filter)
  double _smoothedBearing = -1;

  /// true = 지도가 사용자 위치를 자동으로 따라감
  bool _isFollowing = true;

  /// 코드에서 카메라를 움직이는 동안 onCameraMoveStarted 가 팔로우를 끄지
  /// 않도록 막는 플래그. onCameraIdle 에서 해제된다.
  bool _suppressFollowDisable = false;

  // ── 위치 스트림 / 나침반 스트림 ──────────────────────────────────────────
  StreamSubscription<Position>? _locationSub;
  StreamSubscription<CompassEvent>? _compassSub;
  Position? _lastPosition;

  // ── 일정 데이터 ─────────────────────────────────────────────────────────
  List<_Stop> _allStops = const [];
  List<int> _days = const [1];
  int _selectedDay = 1;
  int _totalMinutes = 0;
  int _currentTransitIndex = 0;

  List<_Stop> get _stops =>
      _allStops.where((s) => s.day == _selectedDay).toList();

  // ── 사용자 현재 구간 ─────────────────────────────────────────────────────
  int _currentSegmentIndex = 0;
  double _segmentProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initStops();
    _markStarted();
    _startLocationTracking();
    _startCompass();
  }

  Future<void> _markStarted() async {
    final scheduleId = widget.trip.scheduleId;
    if (scheduleId == null) return;
    try {
      final detail = await ScheduleApiService.instance.start(scheduleId);
      if (!mounted) return;
      if (detail.stops.isNotEmpty) {
        setState(() => _applyStops(detail.stops));
        final controller = _mapController;
        if (controller != null) await _renderDay(controller);
        return;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _compassSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────── 일정 로드 ──

  void _initStops() {
    final stops = widget.trip.stops;
    if (stops.isNotEmpty) {
      _applyStops(stops);
      _totalMinutes = widget.trip.totalDurationMinutes;
    } else {
      _allStops = _kPlaceholder;
      _days = const [1];
      _selectedDay = 1;
      _totalMinutes = 25;
    }
  }

  void _applyStops(List<TripStop> stops) {
    _allStops = stops
        .map((s) => _Stop(
              day: s.day,
              name: s.name,
              address: s.address,
              time: s.time,
              latLng: LatLng(s.latitude, s.longitude),
              transport: s.transportToNext != null
                  ? _Transport(
                      label: s.transportToNext!.label,
                      duration: '${s.transportToNext!.durationMinutes}분',
                      distance: '${s.transportToNext!.distanceKm}km',
                      path: s.transportToNext!.path
                          ?.map((p) => LatLng(p[0], p[1]))
                          .toList(),
                    )
                  : null,
            ))
        .toList();
    _days = _allStops.map((s) => s.day).toSet().toList()..sort();
    if (_days.isEmpty) _days = const [1];
    if (!_days.contains(_selectedDay)) _selectedDay = _days.first;
    _currentTransitIndex = 0;
  }

  int get _dayMinutes {
    final dayStops = _stops;
    if (_days.length <= 1) return _totalMinutes;
    var sum = 0;
    for (var i = 0; i < dayStops.length; i++) {
      final t = dayStops[i].transport;
      if (t == null) continue;
      sum += int.tryParse(t.duration.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }
    return sum;
  }

  Future<void> _onDaySelected(int day) async {
    if (day == _selectedDay) return;
    setState(() {
      _selectedDay = day;
      _currentTransitIndex = 0;
    });
    final controller = _mapController;
    if (controller != null) await _renderDay(controller);
  }

  static final _kPlaceholder = [
    _Stop(
      name: '속초 버스 터미널',
      address: '강원특별자치도 속초시 중앙로 96',
      time: '09:00',
      latLng: const LatLng(38.2052, 128.5917),
      transport: const _Transport(
          label: '이동: 전동 킥보드', duration: '12분', distance: '1.8km'),
    ),
    _Stop(
      name: '속초해변',
      address: '강원특별자치도 속초시 청호동',
      time: '09:12',
      latLng: const LatLng(38.2014, 128.6008),
      transport:
          const _Transport(label: '이동: 자전거', duration: '13분', distance: '3.8km'),
    ),
    _Stop(
      name: '속초 중앙시장',
      address: '강원특별자치도 속초시 중앙로 147',
      time: '09:25',
      latLng: const LatLng(38.2089, 128.5875),
      transport: null,
    ),
  ];

  String get _totalTimeLabel {
    final minutes = _dayMinutes;
    if (minutes < 60) return '약 $minutes분';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '약 $h시간' : '약 $h시간 $m분';
  }

  // ─────────────────────────────────────────────────────── 위치 추적 ──────

  Future<void> _startLocationTracking() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      return;
    }

    try {
      final initPos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) {
        _updateSegmentProgress(initPos);
        setState(() {});
      }
    } catch (_) {}

    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
      ),
    ).listen(_onPositionUpdate);
  }

  void _startCompass() {
    if (kIsWeb) return;
    _compassSub = FlutterCompass.events?.listen((CompassEvent event) {
      if (!mounted) return;
      final heading = event.heading;
      if (heading != null) setState(() => _deviceHeading = heading);
    });
  }

  double _smoothBearing(double target) {
    if (_smoothedBearing < 0) {
      _smoothedBearing = target;
      return _smoothedBearing;
    }
    final diff = ((target - _smoothedBearing + 540) % 360) - 180;
    _smoothedBearing = (_smoothedBearing + diff * 0.25 + 360) % 360;
    return _smoothedBearing;
  }

  void _updateCurrentLeg(Position pos) {
    final dayStops = _stops;
    if (dayStops.length < 2) return;

    const arrivedMeters = 80.0;
    var nearest = 0;
    var nearestMeters = double.infinity;
    for (var i = 0; i < dayStops.length; i++) {
      final d = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        dayStops[i].latLng.latitude,
        dayStops[i].latLng.longitude,
      );
      if (d < nearestMeters) {
        nearestMeters = d;
        nearest = i;
      }
    }

    final next = nearestMeters <= arrivedMeters
        ? (nearest >= dayStops.length - 1 ? dayStops.length - 2 : nearest)
        : (nearest == 0 ? 0 : nearest - 1);

    if (next != _currentTransitIndex) {
      setState(() => _currentTransitIndex = next);
    }
  }

  Future<void> _onPositionUpdate(Position pos) async {
    if (!mounted) return;
    _lastPosition = pos;
    _updateCurrentLeg(pos);

    final bearing = _smoothBearing(pos.heading);
    _updateSegmentProgress(pos);
    if (mounted) setState(() => _userHeading = bearing);

    if (_isFollowing && _mapController != null) {
      _suppressFollowDisable = true;
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(
          target: LatLng(pos.latitude, pos.longitude),
          zoom: 16,
          bearing: bearing,
        )),
      );
    }
  }

  void _updateSegmentProgress(Position pos) {
    if (_stops.length < 2) return;

    int bestSeg = 0;
    double bestT = 0.0;
    double bestDist = double.infinity;

    for (int i = 0; i < _stops.length - 1; i++) {
      final a = _stops[i].latLng;
      final b = _stops[i + 1].latLng;

      final dLat = b.latitude - a.latitude;
      final dLng = b.longitude - a.longitude;
      final uLat = pos.latitude - a.latitude;
      final uLng = pos.longitude - a.longitude;

      final lenSq = dLat * dLat + dLng * dLng;
      final t = lenSq == 0 ? 0.0 : (uLat * dLat + uLng * dLng) / lenSq;
      final tClamped = t.clamp(0.0, 1.0);

      final closestLat = a.latitude + tClamped * dLat;
      final closestLng = a.longitude + tClamped * dLng;
      final dist = (closestLat - pos.latitude) * (closestLat - pos.latitude) +
          (closestLng - pos.longitude) * (closestLng - pos.longitude);

      if (dist < bestDist) {
        bestDist = dist;
        bestSeg = i;
        bestT = tClamped;
      }
    }

    _currentSegmentIndex = bestSeg;
    _segmentProgress = bestT;
  }

  Future<void> _recenterOnUser() async {
    if (_lastPosition == null || _mapController == null) return;
    setState(() => _isFollowing = true);
    _suppressFollowDisable = true;
    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(
        target: LatLng(_lastPosition!.latitude, _lastPosition!.longitude),
        zoom: 16,
        bearing: _userHeading,
      )),
    );
  }

  Future<void> _resetNorth() async {
    final current = _currentCameraPosition;
    if (_mapController == null || current == null) return;
    _suppressFollowDisable = true;
    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(
        target: current.target,
        zoom: current.zoom,
        bearing: 0,
      )),
    );
  }

  // ─────────────────────────────────────────────────────────── build ──────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap()),
          _buildBackButton(),
          _buildCompassAndLocation(),
          _buildSheet(),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────── 지도 ──────

  Widget _buildMap() {
    final initialTarget = _stops.isNotEmpty
        ? _stops.first.latLng
        : const LatLng(37.5666, 126.9784);
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: initialTarget, zoom: 14),
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      rotateGesturesEnabled: true,
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      onMapCreated: _onMapCreated,
      onCameraMove: (pos) => _currentCameraPosition = pos,
      onCameraMoveStarted: () {
        if (!_suppressFollowDisable && mounted) {
          setState(() => _isFollowing = false);
        }
      },
      onCameraIdle: () => _suppressFollowDisable = false,
    );
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    await _renderDay(controller);
  }

  // 한 번에 한 벌만 그린다. 일차 변경·지도 준비 여러 갈래로 들어오므로
  // pass 번호로 앞선 그리기를 물러나게 한다.
  int _renderPass = 0;
  Future<void>? _renderInFlight;

  Future<void> _renderDay(GoogleMapController controller) async {
    final pass = ++_renderPass;
    final previous = _renderInFlight;
    final done = Completer<void>();
    _renderInFlight = done.future;
    try {
      if (previous != null) await previous;
      await _renderDayPass(controller, pass);
    } finally {
      done.complete();
      if (identical(_renderInFlight, done.future)) _renderInFlight = null;
    }
  }

  Future<void> _renderDayPass(GoogleMapController controller, int pass) async {
    final dayStops = _stops;
    if (dayStops.isEmpty || !mounted) return;
    bool stale() =>
        !mounted || pass != _renderPass || _mapController != controller;

    // 번호 마커
    final markers = <Marker>{};
    for (int i = 0; i < dayStops.length; i++) {
      if (stale()) return;
      final icon = await _makeStopMarker(i + 1);
      if (stale()) return;
      markers.add(Marker(
        markerId: MarkerId('nav_stop_${_selectedDay}_$i'),
        position: dayStops[i].latLng,
        icon: icon,
      ));
    }

    // 경로 폴리라인
    final routeCoords = <LatLng>[];
    void addPoint(LatLng p) {
      if (routeCoords.isEmpty ||
          routeCoords.last.latitude != p.latitude ||
          routeCoords.last.longitude != p.longitude) {
        routeCoords.add(p);
      }
    }
    for (int i = 0; i < dayStops.length - 1; i++) {
      final legPath = dayStops[i].transport?.path;
      final seg = (legPath != null && legPath.length >= 2)
          ? legPath
          : [dayStops[i].latLng, dayStops[i + 1].latLng];
      for (final p in seg) addPoint(p);
    }

    final polylines = <Polyline>{};
    if (routeCoords.length >= 2) {
      polylines.add(Polyline(
        polylineId: PolylineId('nav_route_$_selectedDay'),
        points: routeCoords,
        color: AppColors.primaryScale[400]!,
        width: 6,
      ));
    }

    if (stale()) return;
    setState(() {
      _markers = markers;
      _polylines = polylines;
    });

    // 경로 전체가 보이도록 fitBounds
    final boundsPoints = routeCoords.isNotEmpty
        ? routeCoords
        : dayStops.map((s) => s.latLng).toList();
    final lats = boundsPoints.map((p) => p.latitude);
    final lngs = boundsPoints.map((p) => p.longitude);

    if (stale()) return;
    _suppressFollowDisable = true;
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(lats.reduce(min), lngs.reduce(min)),
          northeast: LatLng(lats.reduce(max), lngs.reduce(max)),
        ),
        80.0,
      ),
    );
  }

  /// 번호가 찍힌 그라디언트 원 마커를 캔버스로 그린다.
  Future<BitmapDescriptor> _makeStopMarker(int number) async {
    const size = 36.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 그림자
    canvas.drawCircle(
      Offset(size / 2, size / 2 + 2),
      size / 2 - 3,
      Paint()
        ..color = AppColors.primaryScale[500]!.withAlpha(0x55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // 그라디언트 원
    final rect = Rect.fromCircle(
        center: Offset(size / 2, size / 2), radius: size / 2 - 3);
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2 - 3,
      Paint()
        ..shader = LinearGradient(
          colors: [
            AppColors.gradientScale[200]!,
            AppColors.gradientScale[600]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect),
    );

    // 숫자
    final tp = TextPainter(
      text: TextSpan(
        text: '$number',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));

    final image =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  // ─────────────────────────────────────────────────────── 뒤로가기 버튼 ──

  Widget _buildBackButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 0, 0),
        child: GestureDetector(
          onTap: () => context.pop(),
          child: _mapCircleButton(
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: AppColors.neutralScale[500],
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────── 나침반 + 내 위치 버튼 ──────

  Widget _buildCompassAndLocation() {
    return Positioned(
      right: 16,
      bottom: MediaQuery.of(context).size.height * 0.46,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _resetNorth,
            child: _mapCircleButton(
              child: AnimatedRotation(
                turns: -_deviceHeading / 360,
                duration: const Duration(milliseconds: 150),
                child: _CompassNeedle(bearing: _deviceHeading),
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _recenterOnUser,
            child: _mapCircleButton(
              highlight: _isFollowing,
              child: Icon(
                Icons.my_location_rounded,
                size: 20,
                color: _isFollowing
                    ? AppColors.primaryScale[500]
                    : AppColors.neutralScale[400],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapCircleButton({required Widget child, bool highlight = false}) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: highlight
            ? Border.all(color: AppColors.primaryScale[300]!, width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(0x28),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(child: child),
    );
  }

  // ─────────────────────────────────────────────────── 드래그 바텀 시트 ──────

  Widget _buildSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.44,
      minChildSize: 0.12,
      maxChildSize: 0.78,
      snap: true,
      snapSizes: const [0.12, 0.44, 0.78],
      builder: (context, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 48),
            children: [
              _buildDragHandle(),
              if (_days.length > 1) ...[
                _buildDayTabs(),
                const SizedBox(height: 16),
              ],
              _buildTotalTime(),
              const SizedBox(height: 4),
              ..._stops.asMap().entries.map((e) => _buildStopItem(
                    e.value,
                    e.key,
                    e.key == _stops.length - 1,
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDayTabs() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final day = _days[i];
          final selected = day == _selectedDay;
          return GestureDetector(
            onTap: () => _onDaySelected(day),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primaryScale[500]
                    : AppColors.neutralScale[100],
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                '$day일차',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.neutralScale[400],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.neutralScale[200],
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  Widget _buildTotalTime() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 14, color: AppColors.neutralScale[400]),
          children: [
            const TextSpan(text: '총 소요시간 : '),
            TextSpan(
              text: _totalTimeLabel,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.neutralScale[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────── 타임라인 아이템 ──────

  Widget _buildStopItem(_Stop stop, int index, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                Container(
                  width: 13,
                  height: 13,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryScale[400]!,
                      width: 2.5,
                    ),
                    color: Colors.white,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: CustomPaint(
                        painter: _SegmentLinePainter(
                          isCompleted: index < _currentSegmentIndex,
                          isCurrent: index == _currentSegmentIndex,
                          progress: _segmentProgress,
                          lineColor: AppColors.primaryScale[400]!,
                          baseColor: AppColors.neutralScale[100]!,
                          dotColor: AppColors.primaryScale[500]!,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          stop.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.neutralScale[600],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        stop.time,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryScale[500],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    stop.address,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.neutralScale[300],
                    ),
                  ),
                  if (stop.transport != null) ...[
                    const SizedBox(height: 10),
                    _buildTransitChip(
                        stop.transport!, index == _currentTransitIndex),
                    const SizedBox(height: 12),
                  ] else
                    const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────── 이동수단 칩 ──────────

  Widget _buildTransitChip(_Transport transport, bool isCurrent) {
    final theme = TransportTheme.byLabel(transport.label);

    if (isCurrent) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.gradientScale[200]!,
              AppColors.gradientScale[600]!,
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryScale[400]!.withAlpha(0x55),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(theme.svgPath, size: 15, color: Colors.white),
            const SizedBox(width: 7),
            Text(
              transport.label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${transport.duration} · ${transport.distance}',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.primaryScale[0],
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(theme.svgPath, size: 15, color: AppColors.primaryScale[400]!),
          const SizedBox(width: 7),
          Text(
            transport.label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryScale[400],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${transport.duration} · ${transport.distance}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.neutralScale[500],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 나침반 바늘 위젯 ─────────────────────────────────────────────────────────

class _CompassNeedle extends StatelessWidget {
  const _CompassNeedle({required this.bearing});

  final double bearing;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(36, 36),
      painter: _CompassPainter(),
    );
  }
}

class _CompassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 8;

    canvas.drawCircle(
      Offset(cx, cy),
      r + 6,
      Paint()
        ..color = AppColors.neutralScale[100]!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final northPath = Path()
      ..moveTo(cx, cy - r * 0.85)
      ..lineTo(cx - r * 0.22, cy + r * 0.1)
      ..lineTo(cx, cy - r * 0.05)
      ..close();
    canvas.drawPath(
      northPath,
      Paint()
        ..color = const Color(0xFFE53935)
        ..style = PaintingStyle.fill,
    );

    final southPath = Path()
      ..moveTo(cx, cy + r * 0.85)
      ..lineTo(cx + r * 0.22, cy - r * 0.1)
      ..lineTo(cx, cy - r * 0.05)
      ..close();
    canvas.drawPath(
      southPath,
      Paint()
        ..color = AppColors.neutralScale[300]!
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      Offset(cx, cy),
      2.0,
      Paint()
        ..color = AppColors.neutralScale[400]!
        ..style = PaintingStyle.fill,
    );

    _drawLabel(canvas, '북', Offset(cx, 3.5), const Color(0xFFE53935));
    _drawLabel(canvas, '남', Offset(cx, size.height - 3.5),
        AppColors.neutralScale[400]!);
    _drawLabel(canvas, '동', Offset(size.width - 3.5, cy),
        AppColors.neutralScale[400]!);
    _drawLabel(canvas, '서', Offset(3.5, cy), AppColors.neutralScale[400]!);
  }

  void _drawLabel(Canvas canvas, String text, Offset center, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 6.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── 구간 선 + 사용자 위치 dot 페인터 ─────────────────────────────────────────
class _SegmentLinePainter extends CustomPainter {
  final bool isCompleted;
  final bool isCurrent;
  final double progress;
  final Color lineColor;
  final Color baseColor;
  final Color dotColor;

  const _SegmentLinePainter({
    required this.isCompleted,
    required this.isCurrent,
    required this.progress,
    required this.lineColor,
    required this.baseColor,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final basePaint = Paint()..color = baseColor;
    final colorPaint = Paint()..color = lineColor;

    canvas.drawRect(Rect.fromLTWH(cx - 1, 0, 2, size.height), basePaint);

    if (isCompleted) {
      canvas.drawRect(Rect.fromLTWH(cx - 1, 0, 2, size.height), colorPaint);
    } else if (isCurrent) {
      final progressY = size.height * progress;
      if (progressY > 0) {
        canvas.drawRect(
            Rect.fromLTWH(cx - 1, 0, 2, progressY), colorPaint);
      }

      const dotRadius = 5.0;
      final dotCenter = Offset(cx, progressY);

      canvas.drawCircle(
        dotCenter,
        dotRadius + 3,
        Paint()
          ..color = dotColor.withAlpha(0x44)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(dotCenter, dotRadius, Paint()..color = Colors.white);
      canvas.drawCircle(
          dotCenter, dotRadius - 2.5, Paint()..color = dotColor);
    }
  }

  @override
  bool shouldRepaint(_SegmentLinePainter old) =>
      old.isCompleted != isCompleted ||
      old.isCurrent != isCurrent ||
      old.progress != progress;
}

// ─── 내부 데이터 모델 ──────────────────────────────────────────────────────────

class _Stop {
  final int day;
  final String name;
  final String address;
  final String time;
  final LatLng latLng;
  final _Transport? transport;

  const _Stop({
    this.day = 1,
    required this.name,
    required this.address,
    required this.time,
    required this.latLng,
    required this.transport,
  });
}

class _Transport {
  final String label;
  final String duration;
  final String distance;

  /// 서버가 내려준 도로 좌표. 없으면 두 방문지를 직선으로 잇는다.
  final List<LatLng>? path;

  const _Transport({
    required this.label,
    required this.duration,
    required this.distance,
    this.path,
  });
}
