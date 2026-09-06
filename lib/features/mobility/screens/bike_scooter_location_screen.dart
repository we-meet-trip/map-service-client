import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../common/theme/app_colors.dart';
import '../../../core/api/bike_station_api_service.dart';
import '../../../core/api/pm_vehicle_api_service.dart';
// 지도 패키지를 직접 부르지 않는다. 그 패키지는 안드로이드·iOS 만 지원해서,
// 웹에서는 화면이 그려지기는 해도 지도와 마커가 통째로 비어 버린다. 다른 지도
// 화면들과 같은 어댑터를 거쳐 실행 환경에 맞는 구현을 받는다.
import '../../../core/maps/map_adapter.dart';
import '../../../core/maps/map_bootstrap.dart';

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
  AppMapController? _mapCtrl;
  double _centerLat = 37.5665; // 서울 시청 (따릉이 서비스 지역)
  double _centerLng = 126.9780;

  // 따릉이 데이터
  final List<MapMarker> _markers = [];
  List<DdallengiStation> _allStations = [];
  DdallengiStation? _selected;

  // 공유 킥보드 데이터.
  //
  // null 은 "아직 못 물어봤거나 조회에 실패했다"이고, 빈 목록은 "물어봤는데
  // 주변에 없다"이다. 둘을 같은 값으로 두면 화면이 "없음"과 "알 수 없음"을
  // 구분하지 못해, 발급처가 멈춘 것을 기기가 없는 것처럼 보여 준다.
  List<PmVehicle>? _pmVehicles;

  // UI 상태
  // 'all' = 전체, 'available' = 대여 가능한 대여소만
  String _filter = 'all';
  bool _loading = false;
  bool _mapMoved = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  // ── 초기 위치 ────────────────────────────────────────────────────────────────
  Future<void> _initLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _centerLat = pos.latitude;
        _centerLng = pos.longitude;
      });
      // 위치를 받는 데는 시간이 걸려서 지도가 먼저 준비되기도 한다. 그러면
      // 대여소 목록은 기본 좌표 주변으로 이미 받아 둔 것인데, 화면은 새 중심
      // 기준으로 5km 를 걸러 내므로 하나도 남지 않는다. 목록을 비워 지금
      // 자리로 다시 받고 지도도 그리로 옮긴다.
      if (_mapCtrl != null) {
        await _recenterTo(_centerLat, _centerLng);
      }
    } catch (_) {}
  }

  /// 지도를 그 자리로 옮기고 대여소 목록을 그 주변으로 다시 받는다.
  ///
  /// 서버는 중심에서 일정 반경 안만 잘라 준다. 중심을 옮겼으면 목록도 함께
  /// 갈아야지, 그대로 두면 옮긴 자리에서는 걸러 낼 것만 남는다.
  Future<void> _recenterTo(double lat, double lng) async {
    await _mapCtrl?.updateCamera(
      MapCameraUpdate.scrollAndZoomTo(
        target: MapCoordinate(lat, lng),
        zoom: 16,
      )..setAnimation(
        animation: MapCameraAnimation.fly,
        duration: const Duration(milliseconds: 700),
      ),
    );
    if (!mounted) return;
    _allStations = [];
    await _loadStations();
  }

  // ── 지도 준비 ────────────────────────────────────────────────────────────────
  Future<void> _onMapReady(AppMapController ctrl) async {
    _mapCtrl = ctrl;
    ctrl.getLocationOverlay().setIsVisible(false);
    await _loadStations();
  }

  // ── 따릉이 대여소 로드 ────────────────────────────────────────────────────────
  Future<void> _loadStations() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _mapMoved = false;
    });
    _clearMarkers();

    // 미로드 시에만 서버 호출 (같은 자리를 다시 그릴 때는 받아 둔 목록 사용).
    // 서버가 지금 보고 있는 자리 주변만 잘라 주므로, 자리를 옮겼을 때는
    // 재탐색이 목록을 비워 여기서 다시 받게 한다.
    if (_allStations.isEmpty) {
      // 대여소와 킥보드는 서로 다른 발급처라 함께 물어도 된다. 차례로 물으면
      // 느린 쪽 시간이 빠른 쪽에 그대로 더해진다.
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

  /// 주변 킥보드 상태를 한 줄 문구로. 그릴 것이 없으면 null.
  ///
  /// "없다"와 "알 수 없다"를 다른 문구로 쓴다. 발급처가 아직 이 지역 자료를
  /// 내주지 않는 동안 "0대"라고만 하면 사용자는 앱이 틀렸다고 여긴다.
  String? get _pmStatusLabel {
    final list = _pmVehicles;
    if (list == null) return '킥보드 정보를 불러오지 못했어요';
    if (list.isEmpty) return '주변에 이용 가능한 킥보드가 없어요';
    return '주변 킥보드 ${list.length}대';
  }

  // ── 마커 렌더링 (중심 5km 이내 + 필터 적용) ─────────────────────────────────
  //
  // 한 번에 한 벌만 그린다. 마커 아이콘은 위젯을 그림 파일로 구워 만드는데, 그
  // 굽는 자리가 앱 전체에서 하나라 두 벌이 겹쳐 돌면 서로의 파일을 지운다.
  // 그러면 아이콘을 읽지 못한 채로 지도에 얹으려다 iOS 에서 앱이 죽는다.
  //
  // 겹치는 경로가 실제로 있다. 지도 식별자가 다음 것으로 바뀌면 지도를 다시
  // 만드는데, 그때 새 지도의 준비 통지가 앞서 돌던 그리기와 겹친다.
  int _renderPass = 0;
  Future<void>? _renderInFlight;

  Future<void> _renderMarkers() async {
    // 번호를 먼저 올린다. 앞서 돌던 그리기가 이 값을 보고 다음 대기 지점에서
    // 스스로 물러난다.
    final pass = ++_renderPass;
    final previous = _renderInFlight;
    final done = Completer<void>();
    _renderInFlight = done.future;
    try {
      // 앞 그리기가 물러날 때까지 기다린 뒤에 시작한다. 기다리지 않고 바로
      // 들어가면 두 벌이 같은 자리에 그림 파일을 굽게 된다.
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
    // 지도가 바뀌었는지도 함께 본다. 번호만으로는 같은 순번에서 지도가 갈린
    // 경우를 못 가른다.
    bool stale() => !mounted || pass != _renderPass || _mapCtrl != ctrl;

    final filtered = _allStations
        .where((s) => s.distanceTo(_centerLat, _centerLng) <= 5000)
        .where((s) => _filter == 'all' || s.parkingBikeTotCnt > 0)
        .toList();

    for (var i = 0; i < filtered.length; i++) {
      if (!mounted || stale()) return;
      final s = filtered[i];
      final icon = await MapOverlayImage.fromWidget(
        widget: _DdalMarkerBubble(availableCount: s.parkingBikeTotCnt),
        size: const Size(52, 34),
        context: context,
      );
      if (stale()) return;
      final marker = MapMarker(
        id: 'ddal_$i',
        position: MapCoordinate(s.lat, s.lng),
        icon: icon,
        anchor: const MapPoint(0.5, 1.0),
      );
      marker.setOnTapListener((_) => _selectStation(s));
      await ctrl.addOverlay(marker);
      if (stale()) return;
      _markers.add(marker);
    }

    // 킥보드는 대여소와 달리 한 대씩 흩어져 있다. 자료가 들어오면 여기서
    // 함께 올라간다 — 지금은 발급처가 이 지역 자료를 내주지 않아 대체로
    // 빈 목록이고, 그때는 이 반복이 그냥 지나간다.
    final vehicles = _pmVehicles ?? const <PmVehicle>[];
    final nearby = vehicles
        .where((v) => v.distanceTo(_centerLat, _centerLng) <= 5000)
        .toList();
    for (var i = 0; i < nearby.length; i++) {
      if (!mounted || stale()) return;
      final v = nearby[i];
      final icon = await MapOverlayImage.fromWidget(
        widget: _PmMarkerBubble(vehicle: v),
        size: const Size(52, 34),
        context: context,
      );
      if (stale()) return;
      final marker = MapMarker(
        id: 'pm_$i',
        position: MapCoordinate(v.lat, v.lng),
        icon: icon,
        anchor: const MapPoint(0.5, 1.0),
      );
      await ctrl.addOverlay(marker);
      if (stale()) return;
      _markers.add(marker);
    }
  }

  void _clearMarkers() {
    // 하나씩 떼지 않고 한꺼번에 비운다. 이 지도에 올라가는 것은 이 화면이
    // 만든 대여소 마커뿐이라 결과가 같고, 하나씩 떼는 방식은 웹 구현에 없어
    // 그쪽에서만 지도가 비어 버린다.
    _mapCtrl?.clearOverlays();
    _markers.clear();
  }

  // ── 대여소 선택 ──────────────────────────────────────────────────────────────
  void _selectStation(DdallengiStation s) {
    setState(() => _selected = s);
    _mapCtrl?.updateCamera(
      MapCameraUpdate.scrollAndZoomTo(target: MapCoordinate(s.lat, s.lng), zoom: 17)
        ..setAnimation(
          animation: MapCameraAnimation.easing,
          duration: const Duration(milliseconds: 500),
        ),
    );
  }

  // ── 필터 ────────────────────────────────────────────────────────────────────
  Future<void> _applyFilter(String f) async {
    if (f == _filter) return;
    setState(() {
      _filter = f;
      _selected = null;
    });
    _clearMarkers();
    await _renderMarkers();
  }

  // ── 이 지역 재탐색 ───────────────────────────────────────────────────────────
  Future<void> _reSearch() async {
    final ctrl = _mapCtrl;
    if (ctrl == null) return;
    final cam = await ctrl.getCameraPosition();
    setState(() {
      _centerLat = cam.target.latitude;
      _centerLng = cam.target.longitude;
      _selected = null;
    });
    // 대여소·킥보드 모두 새 자리 기준으로 다시 받는다.
    setState(() {
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
          perm == LocationPermission.denied) {
        return;
      }
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
          //
          ValueListenableBuilder<int>(
            valueListenable: mapGeneration,
            builder: (context, generation, _) => AppMap(
              key: ValueKey('bike-map-$generation'),
              options: AppMapOptions(
                initialCameraPosition: MapCameraPosition(
                  target: MapCoordinate(_centerLat, _centerLng),
                  zoom: 15,
                ),
                mapType: AppMapType.basic,
                scrollGesturesEnable: true,
                zoomGesturesEnable: true,
                rotationGesturesEnable: false,
                contentPadding: const EdgeInsets.only(bottom: 160),
              ),
              onMapReady: _onMapReady,
              onCameraChange: (reason, _) {
                if (reason == MapCameraUpdateReason.gesture && !_mapMoved) {
                  setState(() => _mapMoved = true);
                }
              },
              onMapTapped: (_, _) {
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
          //
          // 이 화면의 이름과 진입 배너가 "자전거·킥보드"인데 지금까지 지도에는
          // 따릉이만 올라갔다. 킥보드 쪽이 어떤 상태인지 한 줄로 밝혀,
          // 사용자가 "킥보드는 왜 안 보이지"를 묻지 않게 한다.
          if (_pmStatusLabel != null && !_loading)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 58),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
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
            bottom:
                (_selected != null ? 300 : 24) +
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
                valueColor: const AlwaysStoppedAnimation(Color(0xFFEE6C10)),
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
// 따릉이 마커 말풍선
// ──────────────────────────────────────────────────────────────────────────────
/// 킥보드 마커 말풍선.
///
/// 사업자마다 색을 달리해 한 지도에 여러 사업자가 섞여도 구분된다. 배터리를
/// 함께 적는 이유는, 잔량이 적은 기기는 눈앞에 있어도 탈 수 없어서다.
class _PmMarkerBubble extends StatelessWidget {
  final PmVehicle vehicle;
  const _PmMarkerBubble({required this.vehicle});

  /// 사업자 색. 목록에 없는 사업자는 이름을 섞어 색을 정해, 새 사업자가
  /// 들어와도 전부 같은 회색으로 뭉치지 않는다.
  Color get _brandColor {
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
      if (vehicle.providerName.contains(e.key)) return e.value;
    }
    const fallback = [
      Color(0xFFE91E63),
      Color(0xFF9C27B0),
      Color(0xFF3F51B5),
      Color(0xFF00BCD4),
      Color(0xFFFF5722),
    ];
    final name = vehicle.providerName;
    if (name.isEmpty) return const Color(0xFF9E9E9E);
    return fallback[name.codeUnitAt(0) % fallback.length];
  }

  @override
  Widget build(BuildContext context) {
    final color = _brandColor;
    final battery = vehicle.batteryLevel;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x44000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(vehicle.isBike ? '🚲' : '🛴',
                  style: const TextStyle(fontSize: 10)),
              if (battery != null) ...[
                const SizedBox(width: 3),
                Text(
                  '$battery%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
        ),
        CustomPaint(size: const Size(12, 7), painter: _TailPainter(color)),
      ],
    );
  }
}

class _DdalMarkerBubble extends StatelessWidget {
  final int availableCount;
  const _DdalMarkerBubble({required this.availableCount});

  @override
  Widget build(BuildContext context) {
    final color = availableCount > 5
        ? const Color(0xFFEE6C10)
        : availableCount > 0
        ? const Color(0xFFF59E0B)
        : const Color(0xFFBDBDBD);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x44000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🚲', style: TextStyle(fontSize: 10)),
              const SizedBox(width: 3),
              Text(
                '$availableCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        CustomPaint(size: const Size(12, 7), painter: _TailPainter(color)),
      ],
    );
  }
}

class _TailPainter extends CustomPainter {
  final Color color;
  const _TailPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.color != color;
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
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.neutralScale[300],
                ),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: canRent
                    ? const Color(0xFFE6F9EE)
                    : const Color(0xFFF5F5F5),
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
                backgroundColor: canRent ? brandColor : const Color(0xFFE0E0E0),
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
  final Widget trailing;

  const _InfoRow({required this.label, required this.trailing});

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
            style: TextStyle(fontSize: 13, color: AppColors.neutralScale[300]),
          ),
          const Spacer(),
          trailing,
        ],
      ),
    );
  }
}
