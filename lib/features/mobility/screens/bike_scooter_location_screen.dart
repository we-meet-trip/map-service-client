import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../common/theme/app_colors.dart';
import '../../../core/api/bike_station_api_service.dart';
import '../../../core/api/pm_vehicle_api_service.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Screen
// ──────────────────────────────────────────────────────────────────────────────
class BikeScooterLocationScreen extends StatefulWidget {
  const BikeScooterLocationScreen({super.key});

  @override
  State<BikeScooterLocationScreen> createState() =>
      _BikeScooterLocationScreenState();
}

class _BikeScooterLocationScreenState extends State<BikeScooterLocationScreen> {
  // 지도
  GoogleMapController? _mapCtrl;
  double _centerLat = 37.5665;
  double _centerLng = 126.9780;
  CameraPosition? _currentCameraPosition;

  // 따릉이 데이터
  Set<Marker> _markers = const {};
  List<DdallengiStation> _allStations = [];
  DdallengiStation? _selected;

  List<PmVehicle>? _pmVehicles;

  // UI 상태
  String _filter = 'all';
  bool _loading = false;
  bool _mapMoved = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _mapCtrl?.dispose();
    super.dispose();
  }

  // ── 초기 위치 ────────────────────────────────────────────────────────────────
  Future<void> _initLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) return;
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _centerLat = pos.latitude;
        _centerLng = pos.longitude;
      });
      if (_mapCtrl != null) {
        await _recenterTo(_centerLat, _centerLng);
      }
    } catch (_) {}
  }

  Future<void> _recenterTo(double lat, double lng) async {
    await _mapCtrl?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16),
    );
    if (!mounted) return;
    _allStations = [];
    await _loadStations();
  }

  // ── 지도 준비 ────────────────────────────────────────────────────────────────
  Future<void> _onMapCreated(GoogleMapController ctrl) async {
    _mapCtrl = ctrl;
    await _loadStations();
  }

  // ── 따릉이 대여소 로드 ────────────────────────────────────────────────────────
  Future<void> _loadStations() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _mapMoved = false;
      _markers = const {};
    });

    if (_allStations.isEmpty) {
      final results = await Future.wait([
        BikeStationApiService.instance.fetchStations(
          latitude: _centerLat,
          longitude: _centerLng,
        ),
        PmVehicleApiService.instance.fetchVehicles(
          latitude: _centerLat,
          longitude: _centerLng,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _allStations = results[0] as List<DdallengiStation>;
        _pmVehicles = results[1] as List<PmVehicle>?;
      });
    }

    setState(() => _loading = false);
    await _renderMarkers();
  }

  String? get _pmStatusLabel {
    final list = _pmVehicles;
    if (list == null) return '킥보드 정보를 불러오지 못했어요';
    if (list.isEmpty) return '주변에 이용 가능한 킥보드가 없어요';
    return '주변 킥보드 ${list.length}대';
  }

  // ── 마커 렌더링 ─────────────────────────────────────────────────────────────
  int _renderPass = 0;
  Future<void>? _renderInFlight;

  Future<void> _renderMarkers() async {
    final pass = ++_renderPass;
    final previous = _renderInFlight;
    final done = Completer<void>();
    _renderInFlight = done.future;
    try {
      if (previous != null) await previous;
      await _renderMarkersPass(pass);
    } finally {
      done.complete();
      if (identical(_renderInFlight, done.future)) _renderInFlight = null;
    }
  }

  Future<void> _renderMarkersPass(int pass) async {
    final ctrl = _mapCtrl;
    if (ctrl == null || !mounted) return;
    bool stale() => !mounted || pass != _renderPass || _mapCtrl != ctrl;

    final filtered = _allStations
        .where((s) => s.distanceTo(_centerLat, _centerLng) <= 5000)
        .where((s) => _filter == 'all' || s.parkingBikeTotCnt > 0)
        .toList();

    final newMarkers = <Marker>{};

    for (var i = 0; i < filtered.length; i++) {
      if (stale()) return;
      final s = filtered[i];
      final icon = await _makeDdalIcon(s.parkingBikeTotCnt);
      if (stale()) return;
      final station = s;
      newMarkers.add(Marker(
        markerId: MarkerId('ddal_$i'),
        position: LatLng(s.lat, s.lng),
        icon: icon,
        anchor: const Offset(0.5, 1.0),
        onTap: () => _selectStation(station),
      ));
    }

    final vehicles = _pmVehicles ?? const <PmVehicle>[];
    final nearby = vehicles
        .where((v) => v.distanceTo(_centerLat, _centerLng) <= 5000)
        .toList();
    for (var i = 0; i < nearby.length; i++) {
      if (stale()) return;
      final v = nearby[i];
      final icon = await _makePmIcon(v);
      if (stale()) return;
      newMarkers.add(Marker(
        markerId: MarkerId('pm_$i'),
        position: LatLng(v.lat, v.lng),
        icon: icon,
        anchor: const Offset(0.5, 1.0),
      ));
    }

    if (stale()) return;
    setState(() => _markers = newMarkers);
  }

  /// 따릉이 말풍선 마커를 캔버스로 그린다.
  Future<BitmapDescriptor> _makeDdalIcon(int count) async {
    const bw = 52.0;
    const bh = 26.0;
    const tailH = 7.0;
    const r = 12.0;

    final color = count > 5
        ? const Color(0xFFEE6C10)
        : count > 0
            ? const Color(0xFFF59E0B)
            : const Color(0xFFBDBDBD);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 말풍선 몸통
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, bw, bh), const Radius.circular(r)),
      Paint()..color = color,
    );

    // 꼬리 삼각형
    final tail = Path()
      ..moveTo(bw / 2 - 6, bh)
      ..lineTo(bw / 2, bh + tailH)
      ..lineTo(bw / 2 + 6, bh)
      ..close();
    canvas.drawPath(tail, Paint()..color = color);

    // 이모지
    final emoji = TextPainter(
      text: const TextSpan(text: '🚲', style: TextStyle(fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout();
    emoji.paint(canvas, Offset(8, (bh - emoji.height) / 2));

    // 숫자
    final countTp = TextPainter(
      text: TextSpan(
        text: '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    countTp.paint(
        canvas, Offset(8 + emoji.width + 3, (bh - countTp.height) / 2));

    final image = await recorder
        .endRecording()
        .toImage(bw.toInt(), (bh + tailH).toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  /// 킥보드 말풍선 마커를 캔버스로 그린다.
  Future<BitmapDescriptor> _makePmIcon(PmVehicle v) async {
    const bw = 52.0;
    const bh = 26.0;
    const tailH = 7.0;
    const r = 12.0;

    final color = _pmBrandColor(v.providerName);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, bw, bh), const Radius.circular(r)),
      Paint()..color = color,
    );

    final tail = Path()
      ..moveTo(bw / 2 - 6, bh)
      ..lineTo(bw / 2, bh + tailH)
      ..lineTo(bw / 2 + 6, bh)
      ..close();
    canvas.drawPath(tail, Paint()..color = color);

    final emoji = TextPainter(
      text: TextSpan(
          text: v.isBike ? '🚲' : '🛴', style: const TextStyle(fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout();
    emoji.paint(canvas, Offset(6, (bh - emoji.height) / 2));

    final battery = v.batteryLevel;
    if (battery != null) {
      final battTp = TextPainter(
        text: TextSpan(
          text: '$battery%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      battTp.paint(
          canvas, Offset(6 + emoji.width + 3, (bh - battTp.height) / 2));
    }

    final image = await recorder
        .endRecording()
        .toImage(bw.toInt(), (bh + tailH).toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  static Color _pmBrandColor(String name) {
    const brand = {
      'Beam': Color(0xFF4B2FE0),
      'GCOO': Color(0xFF03C75A),
      'SWING': Color(0xFFFF5A36),
      '씽씽': Color(0xFF2196F3),
      '킥고잉': Color(0xFFFF6D00),
      'Lime': Color(0xFF00C853),
      '지쿠': Color(0xFF7B1FA2),
      '알파카': Color(0xFF795548),
    };
    for (final e in brand.entries) {
      if (name.contains(e.key)) return e.value;
    }
    const fallback = [
      Color(0xFFE91E63),
      Color(0xFF9C27B0),
      Color(0xFF3F51B5),
      Color(0xFF00BCD4),
      Color(0xFFFF5722),
    ];
    if (name.isEmpty) return const Color(0xFF9E9E9E);
    return fallback[name.codeUnitAt(0) % fallback.length];
  }

  // ── 대여소 선택 ──────────────────────────────────────────────────────────────
  void _selectStation(DdallengiStation s) {
    setState(() => _selected = s);
    _mapCtrl?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(s.lat, s.lng), 17),
    );
  }

  // ── 필터 ────────────────────────────────────────────────────────────────────
  Future<void> _applyFilter(String f) async {
    if (f == _filter) return;
    setState(() {
      _filter = f;
      _selected = null;
      _markers = const {};
    });
    await _renderMarkers();
  }

  // ── 이 지역 재탐색 ───────────────────────────────────────────────────────────
  Future<void> _reSearch() async {
    final cam = _currentCameraPosition;
    if (cam == null) return;
    setState(() {
      _centerLat = cam.target.latitude;
      _centerLng = cam.target.longitude;
      _selected = null;
      _allStations = [];
      _pmVehicles = null;
    });
    await _loadStations();
  }

  // ── 내 위치 ──────────────────────────────────────────────────────────────────
  Future<void> _goMyLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) return;
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _centerLat = pos.latitude;
        _centerLng = pos.longitude;
        _selected = null;
      });
      await _recenterTo(_centerLat, _centerLng);
    } catch (_) {}
  }

  // ────────────────────────────────────────────────────────────────── build ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── 지도 ──
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(_centerLat, _centerLng),
                zoom: 15,
              ),
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              rotateGesturesEnabled: false,
              scrollGesturesEnabled: true,
              zoomGesturesEnabled: true,
              onMapCreated: _onMapCreated,
              onCameraMove: (pos) => _currentCameraPosition = pos,
              onCameraMoveStarted: () {
                if (!_mapMoved) setState(() => _mapMoved = true);
              },
              onTap: (_) {
                if (_selected != null) setState(() => _selected = null);
              },
            ),
          ),

          // ── 상단 뒤로가기 ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, left: 16),
              child: _CircleButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => context.pop(),
              ),
            ),
          ),

          // ── 타이틀 뱃지 ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, left: 72),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(30),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🚲', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      '서울 따릉이',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.neutralScale[600],
                      ),
                    ),
                    if (_allStations.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEE6C10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_allStations.length}개소',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // ── 킥보드 상태 한 줄 ──
          if (_pmStatusLabel != null && !_loading)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 58),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(235),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(20),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🛴', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 5),
                        Text(
                          _pmStatusLabel!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.neutralScale[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── 이 지역 재탐색 버튼 ──
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 66),
                child: AnimatedSlide(
                  offset: _mapMoved ? Offset.zero : const Offset(0, -0.5),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  child: AnimatedOpacity(
                    opacity: _mapMoved ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: !_mapMoved,
                      child: GestureDetector(
                        onTap: _reSearch,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(45),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_loading)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      Color(0xFFEE6C10),
                                    ),
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.refresh_rounded,
                                  size: 16,
                                  color: Color(0xFFEE6C10),
                                ),
                              const SizedBox(width: 6),
                              Text(
                                _loading ? '불러오는 중...' : '실시간 현황 새로고침',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1B1F23),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── 우측 필터 버튼 ──
          SafeArea(
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _FilterChip(
                      label: '전체',
                      icon: '🚲',
                      active: _filter == 'all',
                      onTap: () => _applyFilter('all'),
                    ),
                    const SizedBox(height: 8),
                    _FilterChip(
                      label: '대여가능',
                      icon: '✅',
                      active: _filter == 'available',
                      onTap: () => _applyFilter('available'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── 내 위치 버튼 ──
          Positioned(
            right: 12,
            bottom: (_selected != null ? 300 : 24) +
                MediaQuery.of(context).padding.bottom,
            child: _CircleButton(
              icon: Icons.my_location_rounded,
              iconColor: const Color(0xFF3478F6),
              onTap: _goMyLocation,
            ),
          ),

          // ── 로딩 오버레이 ──
          if (_loading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor:
                    const AlwaysStoppedAnimation(Color(0xFFEE6C10)),
              ),
            ),

          // ── 따릉이 바텀 시트 ──
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: _selected != null
                ? 0
                : -(300 + MediaQuery.of(context).padding.bottom),
            child: _DdalBottomSheet(
              station: _selected,
              centerLat: _centerLat,
              centerLng: _centerLng,
              onClose: () => setState(() => _selected = null),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 필터 칩
// ──────────────────────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final String icon;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFEE6C10);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 62,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? color : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(30),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: active ? color : AppColors.neutralScale[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 동그란 버튼
// ──────────────────────────────────────────────────────────────────────────────
class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(35),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 20,
          color: iconColor ?? AppColors.neutralScale[500],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 따릉이 바텀 시트
// ──────────────────────────────────────────────────────────────────────────────
class _DdalBottomSheet extends StatelessWidget {
  final DdallengiStation? station;
  final double centerLat;
  final double centerLng;
  final VoidCallback onClose;

  const _DdalBottomSheet({
    required this.station,
    required this.centerLat,
    required this.centerLng,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final s = station;
    final bottom = MediaQuery.of(context).padding.bottom;
    if (s == null) return const SizedBox(height: 300);

    const brandColor = Color(0xFFEE6C10);
    final availableRate = s.rackTotCnt > 0
        ? (s.parkingBikeTotCnt / s.rackTotCnt * 100).round()
        : 0;
    final canRent = s.parkingBikeTotCnt > 0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Color(0x2E000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // 헤더
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: canRent ? brandColor : const Color(0xFFBDBDBD),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text('🚲', style: TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.stationName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.neutralScale[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '서울시 공공자전거 따릉이 · No.${s.stationId}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.neutralScale[300],
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onClose,
                child: Icon(
                  Icons.close,
                  color: AppColors.neutralScale[200],
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 스탯 카드
          Row(
            children: [
              _StatBox(
                label: '대여 가능',
                value: '${s.parkingBikeTotCnt}대',
                valueColor: canRent
                    ? (s.parkingBikeTotCnt > 5
                        ? const Color(0xFF03C75A)
                        : const Color(0xFFF59E0B))
                    : const Color(0xFFE0483F),
              ),
              const SizedBox(width: 10),
              _StatBox(label: '거치대', value: '${s.rackTotCnt}개'),
              const SizedBox(width: 10),
              _StatBox(
                label: '도보 거리',
                value: '${s.distanceTo(centerLat, centerLng)}m',
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 거치율 바
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '거치율',
                style:
                    TextStyle(fontSize: 13, color: AppColors.neutralScale[300]),
              ),
              Text(
                '$availableRate%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutralScale[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: availableRate / 100,
              minHeight: 8,
              backgroundColor: const Color(0xFFF0F0F0),
              valueColor: AlwaysStoppedAnimation(
                availableRate > 50
                    ? const Color(0xFF03C75A)
                    : availableRate > 20
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFE0483F),
              ),
            ),
          ),
          const SizedBox(height: 12),

          _InfoRow(
            label: '대여 상태',
            trailing: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color:
                    canRent ? const Color(0xFFE6F9EE) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                canRent ? '대여 가능' : '자전거 없음',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: canRent
                      ? const Color(0xFF059652)
                      : AppColors.neutralScale[300]!,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 대여 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    canRent ? brandColor : const Color(0xFFE0E0E0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: canRent
                  ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '[따릉이] ${s.stationName} 대여소에서 대여를 시작합니다.',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  : null,
              child: Text(
                canRent ? '대여하기' : '자전거 없음',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 공통 위젯
// ──────────────────────────────────────────────────────────────────────────────
class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatBox({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F7F8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.neutralScale[300],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: valueColor ?? AppColors.neutralScale[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? trailing;

  const _InfoRow({required this.label, this.value, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF4F4F4))),
      ),
      child: Row(
        children: [
          Text(
            label,
            style:
                TextStyle(fontSize: 13, color: AppColors.neutralScale[300]),
          ),
          const Spacer(),
          if (trailing != null)
            trailing!
          else
            Text(
              value ?? '-',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.neutralScale[600],
              ),
            ),
        ],
      ),
    );
  }
}
