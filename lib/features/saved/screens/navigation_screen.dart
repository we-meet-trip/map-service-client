import 'dart:async';
import 'dart:math' show min, max, pi;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../common/theme/app_colors.dart';
import '../../../common/theme/app_icons.dart';
import '../../../core/naver_map/naver_map_adapter.dart';
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
  NaverMapController? _mapController;

  /// 폰 나침반 센서 방위각 (도 단위, 0=북, 시계방향 증가)
  double _deviceHeading = 0.0;

  /// 사용자 이동 방향 (GPS heading, 카메라 재센터링용)
  double _userHeading = 0.0;

  /// true = 지도가 사용자 위치를 자동으로 따라감
  bool _isFollowing = true;

  // ── 위치 스트림 / 나침반 스트림 ──────────────────────────────────────────
  StreamSubscription<Position>? _locationSub;
  StreamSubscription<CompassEvent>? _compassSub;
  Position? _lastPosition;


  // ── 일정 데이터 ─────────────────────────────────────────────────────────
  late final List<_Stop> _stops;
  late final int _totalMinutes;
  final int _currentTransitIndex = 0;

  @override
  void initState() {
    super.initState();
    _initStops();
    _startLocationTracking();
    _startCompass();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _compassSub?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────── 일정 로드 ──

  void _initStops() {
    final stops = widget.trip.stops;
    if (stops.isNotEmpty) {
      _stops = stops
          .map((s) => _Stop(
                name: s.name,
                address: s.address,
                time: s.time,
                latLng: NLatLng(s.latitude, s.longitude),
                transport: s.transportToNext != null
                    ? _Transport(
                        label: s.transportToNext!.label,
                        duration: '${s.transportToNext!.durationMinutes}분',
                        distance: '${s.transportToNext!.distanceKm}km',
                        path: s.transportToNext!.path
                            ?.map((p) => NLatLng(p[0], p[1]))
                            .toList(),
                      )
                    : null,
              ))
          .toList();
      _totalMinutes = widget.trip.totalDurationMinutes;
    } else {
      _stops = _kPlaceholder;
      _totalMinutes = 25;
    }
  }

  static final _kPlaceholder = [
    _Stop(
      name: '속초 버스 터미널',
      address: '강원특별자치도 속초시 중앙로 96',
      time: '09:00',
      latLng: const NLatLng(38.2052, 128.5917),
      transport: const _Transport(
          label: '이동: 전동 킥보드', duration: '12분', distance: '1.8km'),
    ),
    _Stop(
      name: '속초해변',
      address: '강원특별자치도 속초시 청호동',
      time: '09:12',
      latLng: const NLatLng(38.2014, 128.6008),
      transport:
          const _Transport(label: '이동: 자전거', duration: '13분', distance: '3.8km'),
    ),
    _Stop(
      name: '속초 중앙시장',
      address: '강원특별자치도 속초시 중앙로 147',
      time: '09:25',
      latLng: const NLatLng(38.2089, 128.5875),
      transport: null,
    ),
  ];

  String get _totalTimeLabel {
    if (_totalMinutes < 60) return '약 $_totalMinutes분';
    final h = _totalMinutes ~/ 60;
    final m = _totalMinutes % 60;
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

    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3, // 3m 이동할 때마다 갱신
      ),
    ).listen(_onPositionUpdate);
  }

  void _startCompass() {
    // 브라우저에는 나침반을 읽는 수단이 없다. 그대로 두면 구독을 거는 순간
    // 죽는다. 방향 표시만 빠지고 위치 추적과 경로 안내는 그대로 동작한다.
    if (kIsWeb) return;
    _compassSub = FlutterCompass.events?.listen((CompassEvent event) {
      if (!mounted) return;
      final heading = event.heading;
      if (heading != null) {
        setState(() => _deviceHeading = heading);
      }
    });
  }

  Future<void> _onPositionUpdate(Position pos) async {
    if (!mounted) return;
    _lastPosition = pos;

    final latLng = NLatLng(pos.latitude, pos.longitude);

    // ── 1. NLocationOverlay: 파란 점 위치만 (방향 삼각형은 _headingMarker가 담당)
    final overlay = _mapController?.getLocationOverlay();
    overlay?.setIsVisible(true);
    overlay?.setPosition(latLng);

    if (mounted) setState(() => _userHeading = pos.heading);

    // ── 3. 팔로우 모드: 카메라가 사용자를 따라감 ────────────────────────────
    if (_isFollowing && _mapController != null) {
      await _mapController!.updateCamera(
        NCameraUpdate.fromCameraPosition(NCameraPosition(
          target: latLng,
          zoom: 16,
          bearing: pos.heading, // 이동 방향이 위쪽
        ))
          ..setAnimation(
            animation: NCameraAnimation.easing,
            duration: const Duration(milliseconds: 700),
          ),
      );
    }
  }

  // ── 내 위치로 이동 + 팔로우 재개 ──────────────────────────────────────────
  Future<void> _recenterOnUser() async {
    if (_lastPosition == null || _mapController == null) return;

    final latLng =
        NLatLng(_lastPosition!.latitude, _lastPosition!.longitude);
    setState(() => _isFollowing = true);

    await _mapController!.updateCamera(
      NCameraUpdate.fromCameraPosition(NCameraPosition(
        target: latLng,
        zoom: 16,
        bearing: _userHeading,
      ))
        ..setAnimation(
          animation: NCameraAnimation.fly,
          duration: const Duration(milliseconds: 600),
        ),
    );
  }

  // ── 지도를 북쪽 정렬로 리셋 ────────────────────────────────────────────────
  Future<void> _resetNorth() async {
    if (_mapController == null) return;
    final current = await _mapController!.getCameraPosition();
    await _mapController!.updateCamera(
      NCameraUpdate.fromCameraPosition(NCameraPosition(
        target: current.target,
        zoom: current.zoom,
        bearing: 0,
      ))
        ..setAnimation(
          animation: NCameraAnimation.easing,
          duration: const Duration(milliseconds: 400),
        ),
    );
  }

  // ─────────────────────────────────────────────────────────── build ──────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── 지도 전체 배경 ──
          Positioned.fill(child: _buildMap()),
          // ── 방향 삼각형 (Flutter 위젯 오버레이, 팔로우 모드에서 사용자=화면 중앙)
          if (_isFollowing && _lastPosition != null)
            Center(
              child: IgnorePointer(
                child: Transform.rotate(
                  // 지도 카메라 bearing(_userHeading)만큼 보정 후 deviceHeading 적용
                  angle: (_deviceHeading - _userHeading) * pi / 180,
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: CustomPaint(painter: _DirectionTrianglePainter()),
                  ),
                ),
              ),
            ),
          // ── 뒤로가기 ──
          _buildBackButton(),
          // ── 나침반 + 내 위치 버튼 ──
          _buildCompassAndLocation(),
          // ── 하단 정보 시트 ──
          _buildSheet(),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────── 지도 ──────

  Widget _buildMap() {
    return NaverMap(
      options: NaverMapViewOptions(
        initialCameraPosition: NCameraPosition(
          target: _stops.first.latLng,
          zoom: 14,
        ),
        scrollGesturesEnable: true,
        zoomGesturesEnable: true,
        rotationGesturesEnable: true, // 회전 허용 (나침반과 연동)
        mapType: NMapType.basic,
      ),
      onMapReady: _onMapReady,
      onCameraChange: _onCameraChange,
    );
  }

  Future<void> _onMapReady(NaverMapController controller) async {
    _mapController = controller;

    // 번호 마커
    for (int i = 0; i < _stops.length; i++) {
      if (!mounted) return;
      final icon = await NOverlayImage.fromWidget(
        widget: _buildMarkerWidget('${i + 1}'),
        size: const Size(36, 36),
        context: context,
      );
      await controller.addOverlay(NMarker(
        id: 'nav_stop_$i',
        position: _stops[i].latLng,
        icon: icon,
      ));
    }

    // 경로 폴리라인 — 구간마다 도로 좌표가 있으면 그것을, 없으면 두 방문지를
    // 잇는 직선을 이어 붙인다. 일차가 바뀌는 지점은 서버가 이동 정보를 비워
    // 보내므로 그 구간은 직선 폴백으로만 남는다.
    final routeCoords = <NLatLng>[];
    void addPoint(NLatLng p) {
      // 구간 접점의 중복 좌표는 값 비교로 걸러 낸다.
      if (routeCoords.isEmpty ||
          routeCoords.last.latitude != p.latitude ||
          routeCoords.last.longitude != p.longitude) {
        routeCoords.add(p);
      }
    }

    for (int i = 0; i < _stops.length - 1; i++) {
      final legPath = _stops[i].transport?.path;
      final seg = (legPath != null && legPath.length >= 2)
          ? legPath
          : [_stops[i].latLng, _stops[i + 1].latLng];
      for (final p in seg) {
        addPoint(p);
      }
    }

    if (routeCoords.length >= 2) {
      await controller.addOverlay(NPathOverlay(
        id: 'nav_route',
        coords: routeCoords,
        color: AppColors.primaryScale[400]!,
        width: 6,
        outlineColor: Colors.white,
        outlineWidth: 2,
      ));
    }

    // 경로 전체가 보이도록 fitBounds (하단 시트 공간 확보)
    final boundsPoints = routeCoords.isNotEmpty
        ? routeCoords
        : _stops.map((s) => s.latLng).toList();
    final lats = boundsPoints.map((p) => p.latitude);
    final lngs = boundsPoints.map((p) => p.longitude);
    await controller.updateCamera(
      NCameraUpdate.fitBounds(
        NLatLngBounds(
          southWest: NLatLng(lats.reduce(min), lngs.reduce(min)),
          northEast: NLatLng(lats.reduce(max), lngs.reduce(max)),
        ),
        padding: const EdgeInsets.fromLTRB(60, 120, 60, 420),
      )
        ..setAnimation(
          animation: NCameraAnimation.fly,
          duration: const Duration(milliseconds: 900),
        ),
    );

    // ── NLocationOverlay: 파란 점
    final overlay = controller.getLocationOverlay();

    // 맵 준비 전 수신된 GPS 위치가 있으면 즉시 반영
    if (_lastPosition != null) {
      final latLng = NLatLng(_lastPosition!.latitude, _lastPosition!.longitude);
      overlay.setPosition(latLng);
      overlay.setIsVisible(true);
    } else {
      overlay.setIsVisible(false);
    }
  }

  /// 사용자가 지도를 수동으로 드래그하면 팔로우 모드 해제
  void _onCameraChange(NCameraUpdateReason reason, bool animated) {
    if (reason == NCameraUpdateReason.gesture) {
      if (mounted) setState(() => _isFollowing = false);
    }
  }

  Widget _buildMarkerWidget(String number) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.gradientScale[200]!,
            AppColors.gradientScale[600]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryScale[500]!.withAlpha(0x55),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          number,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────── 뒤로가기 버튼 ──────

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
          // ── 나침반 ────────────────────────────────────────────────────
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
          // ── 내 위치로 (팔로우 모드) ───────────────────────────────────
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

  Widget _mapCircleButton({
    required Widget child,
    bool highlight = false,
  }) {
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

  // ─────────────────────────────────────────────── 드래그 바텀 시트 ──────

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
          // 타임라인 점 + 선
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
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.neutralScale[100],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 내용
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
          AppIcon(theme.svgPath,
              size: 15, color: AppColors.primaryScale[400]!),
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
    // 바깥쪽 라벨 영역을 남기고 바늘 반경 설정
    final r = size.width / 2 - 8;

    // 외곽 원
    canvas.drawCircle(
      Offset(cx, cy),
      r + 6,
      Paint()
        ..color = AppColors.neutralScale[100]!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // 북쪽 (빨강)
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

    // 남쪽 (회색)
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

    // 중앙 점
    canvas.drawCircle(
      Offset(cx, cy),
      2.0,
      Paint()
        ..color = AppColors.neutralScale[400]!
        ..style = PaintingStyle.fill,
    );

    // 동서남북 라벨
    _drawLabel(canvas, '북', Offset(cx, 3.5), const Color(0xFFE53935));
    _drawLabel(canvas, '남', Offset(cx, size.height - 3.5), AppColors.neutralScale[400]!);
    _drawLabel(canvas, '동', Offset(size.width - 3.5, cy), AppColors.neutralScale[400]!);
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

// ─── 방향 삼각형 (NMarker 아이콘 전용, 회전은 setAngle()이 담당) ────────────────

class _DirectionTriangle extends StatelessWidget {
  const _DirectionTriangle();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(44, 44),
      painter: _DirectionTrianglePainter(),
    );
  }
}

class _DirectionTrianglePainter extends CustomPainter {
  const _DirectionTrianglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // 삼각형: 위쪽이 바라보는 방향 (setAngle이 이 아이콘을 회전시킴)
    final tipY = cy - 14.0;
    final baseY = cy + 6.0;
    const halfW = 9.0;

    final path = Path()
      ..moveTo(cx, tipY)
      ..lineTo(cx - halfW, baseY)
      ..lineTo(cx + halfW, baseY)
      ..close();

    // 흰 테두리
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
    // 파란 채우기
    canvas.drawPath(path, Paint()..color = const Color(0xFF1A73E8));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── 내부 데이터 모델 ──────────────────────────────────────────────────────────

class _Stop {
  final String name;
  final String address;
  final String time;
  final NLatLng latLng;
  final _Transport? transport;

  const _Stop({
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
  final List<NLatLng>? path;

  const _Transport({
    required this.label,
    required this.duration,
    required this.distance,
    this.path,
  });
}
