import 'dart:async';
import 'dart:math' show min, max, pi;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../common/theme/app_colors.dart';
import '../../../common/theme/app_icons.dart';
import '../../../core/api/schedule_api_service.dart';
import '../../../core/api/trip_api_service.dart';
import '../../../core/naver_map/naver_map_adapter.dart';
import '../../../core/naver_map/naver_map_bootstrap.dart';
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

  /// 카메라 베어링 부드러운 보간용 (low-pass filter)
  double _smoothedBearing = -1;

  /// true = 지도가 사용자 위치를 자동으로 따라감
  bool _isFollowing = true;

  // ── 사용자 위치 마커 (파란 점 대체) ──────────────────────────────────────
  NMarker? _fovMarker;
  NMarker? _ringMarker;
  NMarker? _triangleMarker;
  static const _kFovConeSize  = Size(80, 80);
  static const _kRingSize     = Size(22, 22);
  // 아래쪽 ~9px 간격
  static const _kTriangleSize = Size(22, 26);

  // ── 위치 스트림 / 나침반 스트림 ──────────────────────────────────────────
  StreamSubscription<Position>? _locationSub;
  StreamSubscription<CompassEvent>? _compassSub;
  Position? _lastPosition;


  // ── 일정 데이터 ─────────────────────────────────────────────────────────
  /// 전 일차의 방문지. 화면은 여기서 고른 일차만 그린다.
  List<_Stop> _allStops = const [];
  List<int> _days = const [1];
  int _selectedDay = 1;
  int _totalMinutes = 0;

  /// 지금 이동 중인 구간. 고른 일차 안에서의 순번이다.
  ///
  /// 위치가 갱신될 때마다 가장 가까운 방문지를 찾아 다시 정한다. 고정값으로
  /// 두면 첫 구간이 계속 '현재'로 강조되어, 실제로 어디쯤 왔는지와 화면이
  /// 어긋난 채로 남는다.
  int _currentTransitIndex = 0;

  /// 고른 일차의 방문지만 순서대로.
  List<_Stop> get _stops =>
      _allStops.where((s) => s.day == _selectedDay).toList();

  // ── 사용자 현재 구간 (하단 시트 타임라인 표시용) ───────────────────────────
  int _currentSegmentIndex = 0;   // 현재 위치가 속한 구간 (0 = stop[0]→stop[1])
  double _segmentProgress = 0.0;  // 구간 내 진행도 (0.0 = 출발지, 1.0 = 목적지)

  @override
  void initState() {
    super.initState();
    _initStops();
    _markStarted();
    _startLocationTracking();
    _startCompass();
  }

  /// 이 일정을 따라가기 시작했다고 서버에 알리고, 최신 상세로 갈아 끼운다.
  ///
  /// 저장하지 않은 일정(식별자 없음)은 알릴 대상이 없으므로 건너뛴다.
  /// 실패해도 화면은 이미 들고 온 방문지로 그대로 돌아간다 — 시작 기록이
  /// 안 됐다고 길 안내를 막을 이유가 없다.
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
    } catch (_) {
      // 시작 기록은 부가 동작이라 실패를 화면에 세우지 않는다.
    }
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
      _applyStops(stops);
      _totalMinutes = widget.trip.totalDurationMinutes;
    } else {
      _allStops = _kPlaceholder;
      _days = const [1];
      _selectedDay = 1;
      _totalMinutes = 25;
    }
  }

  /// 서버 방문지를 화면 모델로 옮기고 일차 목록을 다시 세운다.
  ///
  /// 고르고 있던 일차가 새 목록에도 있으면 그대로 둔다 — 시작 기록 응답으로
  /// 목록이 갱신될 때 보고 있던 날이 1일차로 튀지 않게 한다.
  void _applyStops(List<TripStop> stops) {
    _allStops = stops
        .map((s) => _Stop(
              day: s.day,
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
    _days = _allStops.map((s) => s.day).toSet().toList()..sort();
    if (_days.isEmpty) {
      _days = const [1];
    }
    if (!_days.contains(_selectedDay)) {
      _selectedDay = _days.first;
    }
    _currentTransitIndex = 0;
  }

  /// 고른 일차의 이동 시간 합. 여러 날이면 그날 것만 센다.
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
    // 여러 날 일정은 그날 것만 센다. 전 일차 합을 보여주면 오늘 얼마나
    // 움직이는지와 화면 숫자가 어긋난다.
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

    // 화면 진입 즉시 현재 위치로 구간 dot 초기화
    try {
      final initPos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        _updateSegmentProgress(initPos);
        setState(() {});
      }
    } catch (_) {}

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
        _fovMarker?.setAngle(heading);
        _triangleMarker?.setAngle(heading);
      }
    });
  }

  /// GPS heading의 0°/360° 경계를 처리하는 low-pass filter
  double _smoothBearing(double target) {
    if (_smoothedBearing < 0) {
      _smoothedBearing = target;
      return _smoothedBearing;
    }
    // 최단 각도 경로로 보간 (예: 350° → 10° 시 +20° 방향)
    final diff = ((target - _smoothedBearing + 540) % 360) - 180;
    _smoothedBearing = (_smoothedBearing + diff * 0.25 + 360) % 360;
    return _smoothedBearing;
  }

  /// 지금 어느 구간을 가고 있는지 위치로 다시 정한다.
  ///
  /// 가장 가까운 방문지를 찾아, 아직 그곳에 닿지 않았으면 그 앞 구간을,
  /// 이미 닿았으면 그 다음 구간을 현재로 본다. 도착 판정 반경은 도시에서
  /// 위치 오차가 흔히 수십 미터인 점을 감안해 넉넉히 잡았다.
  ///
  /// 구간이 실제로 바뀔 때만 화면을 다시 그린다 — 위치는 3m마다 들어오므로
  /// 매번 setState 하면 목록이 쉬지 않고 흔들린다.
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

    // 마지막 방문지에 닿았으면 더 갈 구간이 없다 — 마지막 구간을 유지한다.
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

    final latLng = NLatLng(pos.latitude, pos.longitude);

    // ── 사용자 위치 마커 업데이트
    _fovMarker?.setPosition(latLng);
    _fovMarker?.setIsVisible(true);
    _ringMarker?.setPosition(latLng);
    _ringMarker?.setIsVisible(true);
    _triangleMarker?.setPosition(latLng);
    _triangleMarker?.setIsVisible(true);

    final bearing = _smoothBearing(pos.heading);
    _updateSegmentProgress(pos);
    if (mounted) setState(() => _userHeading = bearing);

    // ── 팔로우 모드: 카메라가 사용자를 따라감 ────────────────────────────
    if (_isFollowing && _mapController != null) {
      await _mapController!.updateCamera(
        NCameraUpdate.fromCameraPosition(NCameraPosition(
          target: latLng,
          zoom: 16,
          bearing: bearing,
        ))
          ..setAnimation(
            animation: NCameraAnimation.easing,
            duration: const Duration(milliseconds: 1000),
          ),
      );
    }
  }

  // ── 구간 내 사용자 상대 위치 계산 ─────────────────────────────────────────
  /// 각 구간(선분)에 사용자 좌표를 정사영해 가장 가까운 구간과 진행도 t를 구함
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
    // 지도 식별자가 다음 것으로 바뀌면 지도를 다시 만든다. 인증 판정은 지도를
    // 그릴 때 오는데, 그때 이미 만들어진 지도는 처음 식별자로 인증을 끝낸
    // 뒤라 스스로 다시 묻지 않는다 — 다시 만들지 않으면 첫 진입 화면만 계속
    // 비어 있고 나갔다 들어와야 나온다.
    return ValueListenableBuilder<int>(
      valueListenable: naverMapAuthGeneration,
      builder: (context, generation, _) => NaverMap(
        key: ValueKey('nav-map-$generation'),
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
      ),
    );
  }

  Future<void> _onMapReady(NaverMapController controller) async {
    _mapController = controller;
    await _renderDay(controller);

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

  /// 고른 일차의 마커·경로를 다시 그린다.
  ///
  /// 전 일차를 한 줄로 이으면 하루의 마지막 방문지에서 다음 날 첫 방문지까지가
  /// 하나의 이동 구간처럼 보인다. 그 둘 사이에는 잠자리와 하룻밤이 있어서
  /// 길 안내로 이을 구간이 아니다. 그래서 일차마다 따로 그린다.
  // 한 번에 한 벌만 그린다. 안내 시작·일차 변경·지도 준비 세 갈래로 들어오는
  // 데다 지도를 다시 만들면 그것들이 겹친다. 마커 아이콘은 위젯을 그림 파일로
  // 구워 만들고 그 굽는 자리가 앱 전체에 하나뿐이라, 겹쳐 돌면 서로의 파일을
  // 지우고 그 그림을 지도에 얹으려다 iOS 에서 앱이 죽는다.
  int _renderPass = 0;
  Future<void>? _renderInFlight;

  Future<void> _renderDay(NaverMapController controller) async {
    // 번호를 먼저 올린다. 앞서 돌던 그리기가 이 값을 보고 다음 대기 지점에서
    // 스스로 물러난다.
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

  Future<void> _renderDayPass(NaverMapController controller, int pass) async {
    final dayStops = _stops;
    if (dayStops.isEmpty || !mounted) return;
    // 지도가 바뀌었는지도 함께 본다. 번호만으로는 같은 순번에서 지도가 갈린
    // 경우를 못 가른다.
    bool stale() =>
        !mounted || pass != _renderPass || _mapController != controller;

    // 이 화면이 얹는 것은 마커와 경로뿐이라 통째로 지운다. 내 위치 표시는
    // 오버레이 목록이 아니라 컨트롤러가 따로 들고 있어 여기서 지워지지 않는다.
    await controller.clearOverlays();
    if (stale()) return;

    // 번호 마커 — 번호는 그날 안에서 다시 1부터 센다.
    for (int i = 0; i < dayStops.length; i++) {
      if (!mounted || stale()) return;
      final icon = await NOverlayImage.fromWidget(
        widget: _buildMarkerWidget('${i + 1}'),
        size: const Size(36, 36),
        context: context,
      );
      if (stale()) return;
      await controller.addOverlay(NMarker(
        id: 'nav_stop_${_selectedDay}_$i',
        position: dayStops[i].latLng,
        icon: icon,
      ));
      if (stale()) return;
    }

    // 경로 폴리라인 — 구간마다 도로 좌표가 있으면 그것을, 없으면 두 방문지를
    // 잇는 직선을 이어 붙인다.
    final routeCoords = <NLatLng>[];
    void addPoint(NLatLng p) {
      // 구간 접점의 중복 좌표는 값 비교로 걸러 낸다.
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
      for (final p in seg) {
        addPoint(p);
      }
    }

    if (routeCoords.length >= 2) {
      await controller.addOverlay(NPathOverlay(
        id: 'nav_route_$_selectedDay',
        coords: routeCoords,
        color: AppColors.primaryScale[400]!,
        width: 6,
        outlineColor: Colors.white,
        outlineWidth: 2,
      ));
      if (stale()) return;
    }

    // 경로 전체가 보이도록 fitBounds (하단 시트 공간 확보)
    final boundsPoints = routeCoords.isNotEmpty
        ? routeCoords
        : dayStops.map((s) => s.latLng).toList();
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
    if (stale()) return;

    // ── NLocationOverlay(파란 점) 숨김
    controller.getLocationOverlay().setIsVisible(false);

    // ── 사용자 위치 마커 생성 (링 + 삼각형 분리)
    final initPos = _lastPosition != null
        ? NLatLng(_lastPosition!.latitude, _lastPosition!.longitude)
        : _stops.first.latLng;

    if (!mounted || stale()) return;
    final fovIcon = await NOverlayImage.fromWidget(
      widget: const SizedBox(
        width: 80,
        height: 80,
        child: CustomPaint(painter: _FovConePainter()),
      ),
      size: _kFovConeSize,
      context: context,
    );
    if (!mounted || stale()) return;

    final ringIcon = await NOverlayImage.fromWidget(
      widget: const SizedBox(
        width: 22,
        height: 22,
        child: CustomPaint(painter: _RingPainter()),
      ),
      size: _kRingSize,
      context: context,
    );
    if (!mounted || stale()) return;
    final triangleIcon = await NOverlayImage.fromWidget(
      widget: const SizedBox(
        width: 22,
        height: 26,
        child: CustomPaint(painter: _TriangleArrowPainter()),
      ),
      size: _kTriangleSize,
      context: context,
    );
    if (stale()) return;

    _fovMarker = NMarker(
      id: 'user_fov',
      position: initPos,
      icon: fovIcon,
      anchor: const NPoint(0.5, 1.0), // 하단 중앙 = 사용자 위치
      size: _kFovConeSize,
      angle: _deviceHeading,
    );

    _ringMarker = NMarker(
      id: 'user_ring',
      position: initPos,
      icon: ringIcon,
      anchor: const NPoint(0.5, 0.5), // 링 중앙 = 사용자 위치
      size: _kRingSize,
    );
    _triangleMarker = NMarker(
      id: 'user_triangle',
      position: initPos,
      icon: triangleIcon,
      anchor: const NPoint(0.5, 1.0), // 이미지 하단(= 투명 패딩 끝) = 사용자 위치
      size: _kTriangleSize,
      angle: _deviceHeading,
    );

    await controller.addOverlay(_fovMarker!);
    if (stale()) return;
    await controller.addOverlay(_ringMarker!);
    if (stale()) return;
    await controller.addOverlay(_triangleMarker!);
    if (stale()) return;

    if (_lastPosition == null) {
      _fovMarker!.setIsVisible(false);
      _ringMarker!.setIsVisible(false);
      _triangleMarker!.setIsVisible(false);
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

  /// 일차 선택 탭. 하루짜리 일정에는 그리지 않는다.
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

// ─── FOV 콘 마커 (하늘색 부채꼴) ─────────────────────────────────────────────
// 캔버스: 80×80, anchor(0.5, 1.0) → 하단 중앙 = 사용자 위치
// 위쪽(전방)으로 ±30° 부채꼴을 그림

class _FovConePainter extends CustomPainter {
  const _FovConePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height; // 사용자 위치 = 하단 중앙

    const halfAngle = 30.0 * pi / 180; // 30° in radians
    final length = size.height * 0.92;

    // 시작 각도: 캔버스 기준 위쪽(-90°) - halfAngle
    final startAngle = -pi / 2 - halfAngle;

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: length);

    // 방사형 그라디언트: 사용자 위치에서 바깥으로 투명해짐
    final gradient = RadialGradient(
      center: Alignment.bottomCenter,
      radius: 1.0,
      colors: const [
        Color(0xAA00C8FF), // 하늘색, 내부 60% 불투명
        Color(0x1100C8FF), // 하늘색, 외곽 거의 투명
      ],
      stops: const [0.0, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      )
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(cx, cy)
      ..arcTo(rect, startAngle, 2 * halfAngle, false)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── 링 마커 (테두리만) ───────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  const _RingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    const strokeW = 4.3;
    canvas.drawCircle(
      Offset(cx, cy),
      cx - strokeW / 2 - 2.5,
      Paint()
        ..color = const Color(0xFFFF3AB7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── 삼각형(정삼각형 화살표) 마커 ────────────────────────────────────────────
// 캔버스: 22×32 (하단 12px = 투명 패딩 → 링 테두리 두께만큼 간격)

class _TriangleArrowPainter extends CustomPainter {
  const _TriangleArrowPainter();


  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;

    // 정삼각형: 22px 정사각형 영역 안에 stroke로 그림
    const side = 13.0;
    const triH = side * 0.866; // √3/2
    const topY = (22 - triH) / 2;
    const botY = topY + triH;

    // 밑변을 오목하게: cubic bezier로 안쪽으로 파임
    const concaveDepth = 4.0;
    final triangle = Path()
      ..moveTo(cx, topY)
      ..lineTo(cx + side / 2, botY)
      ..cubicTo(
        cx + side / 4, botY - concaveDepth,
        cx - side / 4, botY - concaveDepth,
        cx - side / 2, botY,
      )
      ..close();

    canvas.drawPath(
      triangle,
      Paint()
        ..color = const Color(0xFFFF3AB7)
        ..style = PaintingStyle.fill,
    );
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

    // 베이스 선 (회색 전체)
    canvas.drawRect(Rect.fromLTWH(cx - 1, 0, 2, size.height), basePaint);

    if (isCompleted) {
      // 완료 구간: 전체 컬러
      canvas.drawRect(Rect.fromLTWH(cx - 1, 0, 2, size.height), colorPaint);
    } else if (isCurrent) {
      // 현재 구간: 진행된 부분만 컬러
      final progressY = size.height * progress;
      if (progressY > 0) {
        canvas.drawRect(
            Rect.fromLTWH(cx - 1, 0, 2, progressY), colorPaint);
      }

      // 사용자 위치 dot
      const dotRadius = 5.0;
      final dotCenter = Offset(cx, progressY);

      // 글로우 (그림자)
      canvas.drawCircle(
        dotCenter,
        dotRadius + 3,
        Paint()
          ..color = dotColor.withAlpha(0x44)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      // 흰 테두리
      canvas.drawCircle(dotCenter, dotRadius, Paint()..color = Colors.white);
      // 컬러 fill
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
  /// 이 방문지가 속한 여행 일차(1부터). 하루짜리 일정은 전부 1이다.
  final int day;
  final String name;
  final String address;
  final String time;
  final NLatLng latLng;
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
  final List<NLatLng>? path;

  const _Transport({
    required this.label,
    required this.duration,
    required this.distance,
    this.path,
  });
}
