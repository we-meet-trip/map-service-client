import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../common/theme/app_colors.dart';
import '../../../core/api/api_client.dart';

// ──────────────────────────────────────────────────────────────────────────────
// 따릉이 대여소 모델
// ──────────────────────────────────────────────────────────────────────────────
class DdallengiStation {
  final String stationId;
  final String stationName;
  final int rackTotCnt;
  final int parkingBikeTotCnt;
  final double lat;
  final double lng;

  /// 서버가 준 한 줄을 읽는다.
  ///
  /// 이름이 서버와 화면에서 다르다. 서버는 밑줄로 잇고 화면은 옛 발급처
  /// 이름을 그대로 쓴다. 이 짝짓기가 어긋나면 대여소가 전부 0으로 보이는데,
  /// 그 모습은 "자전거가 없는 대여소" 와 구분되지 않는다.
  factory DdallengiStation.fromServer(Map<String, dynamic> row) =>
      DdallengiStation(
        stationId: '${row['station_id'] ?? ''}',
        stationName: '${row['name'] ?? ''}',
        rackTotCnt: (row['rack_total'] as num?)?.toInt() ?? 0,
        parkingBikeTotCnt: (row['parking_bike_total'] as num?)?.toInt() ?? 0,
        lat: (row['lat'] as num?)?.toDouble() ?? 0,
        lng: (row['lng'] as num?)?.toDouble() ?? 0,
      );

  const DdallengiStation({
    required this.stationId,
    required this.stationName,
    required this.rackTotCnt,
    required this.parkingBikeTotCnt,
    required this.lat,
    required this.lng,
  });

  int distanceTo(double userLat, double userLng) {
    const R = 6371000.0;
    final dLat = (lat - userLat) * pi / 180;
    final dLng = (lng - userLng) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(userLat * pi / 180) *
            cos(lat * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return (R * 2 * atan2(sqrt(a), sqrt(1 - a))).round();
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 따릉이 대여소 조회
//
// 발급처를 앱이 직접 부르지 않는다. 그러면 인증키가 앱 꾸러미에 함께 실려
// 나가고, 그 발급처는 평문으로만 받아서 배포본에서는 아예 닿지 못한다.
// 서버가 대신 물어 오면 키는 서버에만 남고 앱은 https 로만 말한다.
//
// 서버는 좌표 주변 반경으로 준다. 화면이 어차피 중심에서 5km 안만 그리므로
// 같은 값을 반경으로 넘긴다.
// ──────────────────────────────────────────────────────────────────────────────
Future<List<DdallengiStation>> fetchDdallengiStations(
  double lat,
  double lng, {
  int radiusM = 5000,
}) async {
  try {
    final body = await ApiClient.instance.get(
      '/api/v1/mobility/bike-stations',
      query: {'lat': '$lat', 'lng': '$lng', 'radiusM': '$radiusM'},
    );
    final rows = body['stations'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(DdallengiStation.fromServer)
        .where((s) => s.lat != 0 && s.lng != 0)
        .toList();
  } catch (_) {
    // 조회에 실패하면 빈 목록으로 둔다. 화면은 대여소가 없다고 표시한다.
    return const [];
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Screen
// ──────────────────────────────────────────────────────────────────────────────
class BikeScooterLocationScreen extends StatefulWidget {
  const BikeScooterLocationScreen({super.key});

  @override
  State<BikeScooterLocationScreen> createState() =>
      _BikeScooterLocationScreenState();
}

class _BikeScooterLocationScreenState
    extends State<BikeScooterLocationScreen> {
  // 지도
  NaverMapController? _mapCtrl;
  double _centerLat = 37.5665; // 서울 시청 (따릉이 서비스 지역)
  double _centerLng = 126.9780;

  // 따릉이 데이터
  final List<NMarker> _markers = [];
  List<DdallengiStation> _allStations = [];
  DdallengiStation? _selected;

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
          perm == LocationPermission.denied) return;
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _centerLat = pos.latitude;
        _centerLng = pos.longitude;
      });
    } catch (_) {}
  }

  // ── 지도 준비 ────────────────────────────────────────────────────────────────
  Future<void> _onMapReady(NaverMapController ctrl) async {
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

    // 서버가 중심 주변만 주므로 지도를 옮기면 그 자리로 다시 물어야 한다.
    // 한 번만 받아 두면 옮긴 곳에는 아무것도 뜨지 않는다.
    final stations = await fetchDdallengiStations(_centerLat, _centerLng);
    if (!mounted) return;
    setState(() => _allStations = stations);

    setState(() => _loading = false);
    await _renderMarkers();
  }

  // ── 마커 렌더링 (중심 5km 이내 + 필터 적용) ─────────────────────────────────
  Future<void> _renderMarkers() async {
    final ctrl = _mapCtrl;
    if (ctrl == null || !mounted) return;

    final filtered = _allStations
        .where((s) => s.distanceTo(_centerLat, _centerLng) <= 5000)
        .where((s) => _filter == 'all' || s.parkingBikeTotCnt > 0)
        .toList();

    final ctx = context;
    for (var i = 0; i < filtered.length; i++) {
      final s = filtered[i];
      final icon = await NOverlayImage.fromWidget(
        widget: _DdalMarkerBubble(availableCount: s.parkingBikeTotCnt),
        size: const Size(52, 34),
        context: ctx,
      );
      if (!mounted) return;
      final marker = NMarker(
        id: 'ddal_$i',
        position: NLatLng(s.lat, s.lng),
        icon: icon,
        anchor: const NPoint(0.5, 1.0),
      );
      marker.setOnTapListener((_) => _selectStation(s));
      await ctrl.addOverlay(marker);
      _markers.add(marker);
    }
  }

  void _clearMarkers() {
    final ctrl = _mapCtrl;
    for (final m in _markers) {
      ctrl?.deleteOverlay(m.info);
    }
    _markers.clear();
  }

  // ── 대여소 선택 ──────────────────────────────────────────────────────────────
  void _selectStation(DdallengiStation s) {
    setState(() => _selected = s);
    _mapCtrl?.updateCamera(
      NCameraUpdate.scrollAndZoomTo(
        target: NLatLng(s.lat, s.lng),
        zoom: 17,
      )..setAnimation(
          animation: NCameraAnimation.easing,
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
    // 따릉이 데이터 새로고침 (실시간 대여 현황 업데이트)
    setState(() => _allStations = []);
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
      await _mapCtrl?.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(_centerLat, _centerLng),
          zoom: 16,
        )..setAnimation(
            animation: NCameraAnimation.fly,
            duration: const Duration(milliseconds: 700),
          ),
      );
      _clearMarkers();
      await _renderMarkers();
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
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: NLatLng(_centerLat, _centerLng),
                zoom: 15,
              ),
              mapType: NMapType.basic,
              scrollGesturesEnable: true,
              zoomGesturesEnable: true,
              rotationGesturesEnable: false,
              logoAlign: NLogoAlign.leftBottom,
            ),
            onMapReady: _onMapReady,
            onCameraChange: (reason, _) {
              if (reason == NCameraUpdateReason.gesture && !_mapMoved) {
                setState(() => _mapMoved = true);
              }
            },
            onMapTapped: (_, __) {
              if (_selected != null) setState(() => _selected = null);
            },
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                            horizontal: 8, vertical: 2),
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

          // ── 이 지역 재탐색 버튼 ──
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 66),
                child: AnimatedSlide(
                  offset:
                      _mapMoved ? Offset.zero : const Offset(0, -0.5),
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
                              horizontal: 18, vertical: 10),
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
                                        Color(0xFFEE6C10)),
                                  ),
                                )
                              else
                                const Icon(Icons.refresh_rounded,
                                    size: 16,
                                    color: Color(0xFFEE6C10)),
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
// 따릉이 마커 말풍선
// ──────────────────────────────────────────────────────────────────────────────
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
        CustomPaint(
          size: const Size(12, 7),
          painter: _TailPainter(color),
        ),
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
        child: Icon(icon,
            size: 20, color: iconColor ?? AppColors.neutralScale[500]),
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
    final availableRate =
        s.rackTotCnt > 0 ? (s.parkingBikeTotCnt / s.rackTotCnt * 100).round() : 0;
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
                child: Icon(Icons.close,
                    color: AppColors.neutralScale[200], size: 22),
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
              _StatBox(
                label: '거치대',
                value: '${s.rackTotCnt}개',
              ),
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
                              '[따릉이] ${s.stationName} 대여소에서 대여를 시작합니다.'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  : null,
              child: Text(
                canRent ? '대여하기' : '자전거 없음',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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

  const _StatBox({
    required this.label,
    required this.value,
    this.valueColor,
  });

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
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: AppColors.neutralScale[300])),
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
          Text(label,
              style: TextStyle(
                  fontSize: 13, color: AppColors.neutralScale[300])),
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
