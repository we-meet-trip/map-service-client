import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/theme/app_icons.dart';
import '../widgets/transport_theme.dart';
import '../../../common/widgets/next_button.dart';
import '../../../common/widgets/prev_button.dart';
import '../../../core/state/trip_repository.dart';
import '../../../common/widgets/text_field.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/schedule_api_service.dart';
import '../../../core/api/trip_api_service.dart';
import '../../../core/router/app_router.dart';
import '../../auth/widgets/kakao_login_button.dart';
import '../../../common/widgets/draggable_vision_button.dart';
import '../widgets/place_detail_sheet.dart';

class GoogleTripCreatedScreen extends StatefulWidget {
  const GoogleTripCreatedScreen({
    super.key,
    this.showBackButton = false,
    this.onPrev,
    this.response,
    this.startDate,
    this.endDate,
    this.savedTrip,
  });

  final bool showBackButton;
  final VoidCallback? onPrev;
  final TripGenerateResponse? response;
  final DateTime? startDate;
  final DateTime? endDate;
  final SavedTrip? savedTrip;

  @override
  State<GoogleTripCreatedScreen> createState() =>
      _GoogleTripCreatedScreenState();
}

class _GoogleTripCreatedScreenState extends State<GoogleTripCreatedScreen> {
  late bool _isSaved = widget.showBackButton;
  bool _shouldAutoSave = false;

  /// 이 화면이 가리키는 저장된 일정 — 「일정 시작하기」가 넘겨줄 대상.
  ///
  /// 저장 목록에서 열었으면 처음부터 채워져 있고, 방금 만든 일정을 여기서
  /// 저장하면 그때 채워진다. 생성자 필드를 그대로 쓰면 저장에 성공해도
  /// 값이 계속 비어 있어, 저장을 마친 사용자에게 시작할 방법이 없어진다.
  late SavedTrip? _startTarget = widget.savedTrip;

  late final List<_ScheduleStop> _stops;
  late final int _totalDurationMinutes;
  late final List<int> _days;
  late int _selectedDay;

  GoogleMapController? _mapController;
  Set<Marker> _markers = const {};
  Set<Polyline> _polylines = const {};

  @override
  void initState() {
    super.initState();
    final saved = widget.savedTrip;
    final res = widget.response;
    if (saved != null) {
      _stops = saved.stops.map(_fromApiStop).toList();
      _totalDurationMinutes = saved.totalDurationMinutes;
    } else if (res != null) {
      _stops = res.stops.map(_fromApiStop).toList();
      _totalDurationMinutes = res.totalDurationMinutes;
    } else {
      _stops = _placeholder;
      _totalDurationMinutes = 25;
    }
    _days = _stops.map((s) => s.day).toSet().toList()..sort();
    _selectedDay = _days.isNotEmpty ? _days.first : 1;
    // 로그인 후 복귀 시 자동으로 저장 바텀시트 열기
    if (TripRepository.instance.autoSaveOnNext && isAuthenticated.value) {
      TripRepository.instance.autoSaveOnNext = false;
      _shouldAutoSave = true;
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  List<_ScheduleStop> get _selectedDayStops =>
      _stops.where((s) => s.day == _selectedDay).toList();

  static _ScheduleStop _fromApiStop(TripStop s) => _ScheduleStop(
        day: s.day,
        name: s.name,
        address: s.address,
        time: s.time,
        latLng: LatLng(s.latitude, s.longitude),
        category: s.category,
        placeId: s.placeId,
        transport: s.transportToNext != null
            ? _TransportInfo(
                label: s.transportToNext!.label,
                duration: '${s.transportToNext!.durationMinutes}분',
                distance: '${s.transportToNext!.distanceKm}km',
                path: s.transportToNext!.path
                    ?.map((p) => LatLng(p[0], p[1]))
                    .toList(),
              )
            : null,
      );

  static final List<_ScheduleStop> _placeholder = [
    _ScheduleStop(
      day: 1,
      name: '속초 버스 터미널',
      address: '강원특별자치도 속초시 중앙로 96',
      time: '09:00',
      latLng: const LatLng(38.2052, 128.5917),
      transport: _TransportInfo(
        label: '이동: 전동 킥보드',
        duration: '12분',
        distance: '1.8km',
      ),
    ),
    _ScheduleStop(
      day: 1,
      name: '속초해변',
      address: '강원특별자치도 속초시 청호동',
      time: '09:12',
      latLng: const LatLng(38.2014, 128.6008),
      transport: _TransportInfo(
        label: '이동: 자전거',
        duration: '13분',
        distance: '3.8km',
      ),
    ),
    _ScheduleStop(
      day: 1,
      name: '속초 중앙시장',
      address: '강원특별자치도 속초시 중앙로 147',
      time: '09:25',
      latLng: const LatLng(38.2089, 128.5875),
      transport: null,
    ),
  ];

  int _minutesSinceMidnight(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  String get _totalTimeLabel {
    final minutes = _days.length <= 1
        ? _totalDurationMinutes
        : _dayDurationMinutes(_selectedDayStops);
    if (minutes < 60) return '약 $minutes분';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '약 $h시간' : '약 $h시간 $m분';
  }

  int _dayDurationMinutes(List<_ScheduleStop> dayStops) {
    if (dayStops.length < 2) return 0;
    final start = _minutesSinceMidnight(dayStops.first.time);
    final end = _minutesSinceMidnight(dayStops.last.time);
    return end - start;
  }

  void _onDaySelected(int day) {
    if (day == _selectedDay) return;
    setState(() => _selectedDay = day);
    final controller = _mapController;
    if (controller != null) _renderDayOverlays(controller);
  }

  @override
  Widget build(BuildContext context) {
    if (_shouldAutoSave) {
      _shouldAutoSave = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showSaveBottomSheet(context);
      });
    }
    return _buildBody(context);
  }

  Widget _buildBody(BuildContext context) {
    final saved = widget.savedTrip;
    return Column(
      children: [
        // ── 저장 탭에서 열렸을 때 뒤로가기 헤더 (savedTrip 없이 열린 경우) ──
        if (widget.showBackButton && saved == null)
          SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: AppColors.neutralScale[500]),
                    onPressed: () => context.go('/saved'),
                  ),
                  Text(
                    '저장된 일정',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutralScale[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
        // ── 스크롤 영역 ──
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                saved != null ? _buildMapAreaWithBackButton() : _buildMapArea(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      saved != null ? _buildSavedTripHeader(saved) : _buildTitle(),
                      const SizedBox(height: 16),
                      if (_warnings.isNotEmpty) ...[
                        _buildWarningsNotice(),
                        const SizedBox(height: 16),
                      ],
                      if (_days.length > 1) ...[
                        _buildDayTabs(),
                        const SizedBox(height: 16),
                      ],
                      _buildTotalTime(),
                      const SizedBox(height: 28),
                      ..._selectedDayStops.asMap().entries.map((entry) =>
                          _buildStopItem(entry.value,
                              entry.key == _selectedDayStops.length - 1)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── 하단 고정 버튼 ──
        if (saved != null)
          _buildSavedTripBottomButton(context)
        else if (!widget.showBackButton)
          _buildBottomButtons(context),
      ],
    );
  }

  /// 추천에 반영하지 못한 조건 안내. 생성 응답과 저장 상세 어느 쪽으로
  /// 열렸든 서버가 준 문장을 그대로 보여준다.
  List<String> get _warnings =>
      widget.response?.warnings ?? widget.savedTrip?.warnings ?? const [];

  Widget _buildWarningsNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _warnings
            .map((line) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(Icons.info_outline_rounded,
                          size: 16, color: Color(0xFFB98A00)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        line,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Color(0xFF7A5C00),
                        ),
                      ),
                    ),
                  ],
                ))
            .toList(),
      ),
    );
  }

  // ── 지도 영역 ────────────────────────────────────────────────

  Widget _buildMapArea() {
    return SizedBox(
      width: double.infinity,
      height: 280,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _selectedDayStops.isNotEmpty
              ? _selectedDayStops.first.latLng
              : _stops.first.latLng,
          zoom: 14,
        ),
        markers: _markers,
        polylines: _polylines,
        onMapCreated: _onMapCreated,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        scrollGesturesEnabled: true,
        zoomGesturesEnabled: true,
        rotateGesturesEnabled: false,
        gestureRecognizers: {
          Factory<OneSequenceGestureRecognizer>(
            () => EagerGestureRecognizer(),
          ),
        },
      ),
    );
  }

  Widget _buildMapAreaWithBackButton() {
    return Stack(
      children: [
        _buildMapArea(),
        Positioned(
          top: 12,
          left: 12,
          child: SafeArea(
            bottom: false,
            child: GestureDetector(
              onTap: () => context.go('/saved'),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neutralScale[600]!.withAlpha(0x1A),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16, color: AppColors.neutralScale[600]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    await _renderDayOverlays(controller);
  }

  // 한 번에 한 벌만 그린다. 일차를 바꿀 때와 지도가 준비될 때 각각 들어오는데,
  // 지도를 다시 만들면 그 둘이 겹친다. 마커 아이콘은 위젯을 그림 파일로 구워
  // 만들고 그 굽는 자리가 앱 전체에 하나뿐이라, 겹쳐 돌면 서로의 파일을 지우고
  // 그 그림을 지도에 얹으려다 iOS 에서 앱이 죽는다.
  int _renderPass = 0;
  Future<void>? _renderInFlight;

  Future<void> _renderDayOverlays(GoogleMapController controller) async {
    // 번호를 먼저 올린다. 앞서 돌던 그리기가 이 값을 보고 다음 대기 지점에서
    // 스스로 물러난다.
    final pass = ++_renderPass;
    final previous = _renderInFlight;
    final done = Completer<void>();
    _renderInFlight = done.future;
    try {
      if (previous != null) await previous;
      await _renderDayOverlaysPass(controller, pass);
    } finally {
      done.complete();
      if (identical(_renderInFlight, done.future)) _renderInFlight = null;
    }
  }

  Future<void> _renderDayOverlaysPass(
      GoogleMapController controller, int pass) async {
    final stops = _selectedDayStops;
    if (stops.isEmpty || !mounted) return;
    // 지도가 바뀌었는지도 함께 본다. 번호만으로는 같은 순번에서 지도가 갈린
    // 경우를 못 가른다.
    bool stale() =>
        !mounted || pass != _renderPass || _mapController != controller;

    // 마커 생성
    final markers = <Marker>{};
    for (int i = 0; i < stops.length; i++) {
      if (stale()) return;
      final icon = await _makeNumberedMarker('${i + 1}');
      if (stale()) return;
      markers.add(Marker(
        markerId: MarkerId('stop_$i'),
        position: stops[i].latLng,
        icon: icon,
        infoWindow: InfoWindow(title: stops[i].name, snippet: stops[i].time),
      ));
    }

    // 경로 폴리라인 추가 — 구간마다 도로 추종 path 가 있으면 그 좌표를,
    // 없으면 두 stop 을 잇는 직선을 이어 붙여 하나의 경로로 그린다.
    // 선택된 일차 안에서만 잇는다. 마지막 stop 의 이동 정보는 다음 날 첫
    // 장소로 이어지므로 여기서 쓰지 않는다(서버도 그 자리를 비워 보낸다).
    final routeCoords = <LatLng>[];
    void addPoint(LatLng p) {
      // 구간 접점의 중복 좌표는 값 비교로 걸러 낸다.
      if (routeCoords.isEmpty ||
          routeCoords.last.latitude != p.latitude ||
          routeCoords.last.longitude != p.longitude) {
        routeCoords.add(p);
      }
    }

    for (int i = 0; i < stops.length - 1; i++) {
      final legPath = stops[i].transport?.path;
      final seg = (legPath != null && legPath.length >= 2)
          ? legPath
          : [stops[i].latLng, stops[i + 1].latLng];
      for (final p in seg) {
        addPoint(p);
      }
    }

    if (stale()) return;

    setState(() {
      _markers = markers;
      _polylines = routeCoords.length >= 2
          ? {
              Polyline(
                polylineId: const PolylineId('route'),
                points: routeCoords,
                color: AppColors.primaryScale[400]!,
                width: 6,
              ),
            }
          : const {};
    });

    if (stale()) return;

    // 경로 전체(마커+도로 굴곡 포함)가 보이도록 fitBounds. 경로가 없으면 stop 기준.
    final boundsPoints = routeCoords.isNotEmpty
        ? routeCoords
        : stops.map((s) => s.latLng).toList();
    final lats = boundsPoints.map((p) => p.latitude);
    final lngs = boundsPoints.map((p) => p.longitude);
    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(lats.reduce(min), lngs.reduce(min)),
          northeast: LatLng(lats.reduce(max), lngs.reduce(max)),
        ),
        56.0,
      ),
    );
  }

  Future<BitmapDescriptor> _makeNumberedMarker(String number) async {
    const size = 48.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawCircle(
        const Offset(size / 2, size / 2 + 1),
        size / 2 - 3,
        Paint()
          ..color = Colors.black.withAlpha(0x26)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 3,
        Paint()..color = Colors.white);
    canvas.drawCircle(
        const Offset(size / 2, size / 2),
        size / 2 - 3,
        Paint()
          ..color = AppColors.primaryScale[400]!
          ..strokeWidth = 3.0
          ..style = PaintingStyle.stroke);
    final tp = TextPainter(
      text: TextSpan(
          text: number,
          style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryScale[500])),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));
    final image = await recorder
        .endRecording()
        .toImage(size.toInt(), size.toInt());
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  // ── 제목 / 소요시간 ──────────────────────────────────────────

  Widget _buildTitle() {
    if (widget.showBackButton) {
      final savedAt = widget.savedTrip?.savedAt;
      final dateStr = savedAt != null
          ? '${savedAt.year}.${savedAt.month.toString().padLeft(2, '0')}.${savedAt.day.toString().padLeft(2, '0')}'
          : '';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.savedTrip?.name ?? '저장된 일정',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.neutralScale[600],
              height: 1.2,
            ),
          ),
          if (dateStr.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 13, color: AppColors.neutralScale[300]),
                const SizedBox(width: 4),
                Text(
                  dateStr,
                  style: TextStyle(
                      fontSize: 13, color: AppColors.neutralScale[300]),
                ),
              ],
            ),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '일정이 완성되었어요!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.neutralScale[600],
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '일정을 검토하고 경로를 확정해주세요.',
          style: TextStyle(fontSize: 13, color: AppColors.neutralScale[300]),
        ),
      ],
    );
  }

  Widget _buildSavedTripHeader(SavedTrip saved) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                saved.name,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutralScale[600],
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _fmtDate(saved.tripStartDate),
                style: TextStyle(fontSize: 14, color: AppColors.savedBadgeFar),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => context.push('/saved/trip/directions', extra: saved),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.savedBadgeUrgent, AppColors.tripDirectionsPinkEnd],
              ),
              borderRadius: BorderRadius.circular(100),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neutralScale[600]!.withAlpha(0x0F),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Text(
              '가는 방법 알아보기',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _fmtDate(DateTime dt) =>
      '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';

  // ── 일차 탭 ──────────────────────────────────────────────────

  Widget _buildDayTabs() {
    return Stack(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _days
                .map((day) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildDayTab(day),
                    ))
                .toList(),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
              width: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    AppColors.background,
                    AppColors.background.withAlpha(0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDayTab(int day) {
    final isSelected = day == _selectedDay;
    return GestureDetector(
      onTap: () => _onDaySelected(day),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondaryScale[200]!.withAlpha(153) : null,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          '$day일차',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.gradientScale[500] : AppColors.neutralScale[300],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalTime() {
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 14, color: AppColors.neutralScale[400]),
        children: [
          const TextSpan(text: '총 소요시간 : '),
          TextSpan(
            text: _totalTimeLabel,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primaryScale[500],
            ),
          ),
        ],
      ),
    );
  }

  // ── 일정 아이템 ──────────────────────────────────────────────

  Widget _buildStopItem(_ScheduleStop stop, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타임라인
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryScale[300]!, width: 2),
                    color: Colors.white,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.neutralScale[100],
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 내용
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 장소를 누르면 지도 카메라가 해당 위치로 이동하고, 상세 시트도 뜬다.
                InkWell(
                  onTap: () {
                    _mapController?.animateCamera(
                        CameraUpdate.newLatLng(stop.latLng));
                    showPlaceDetailSheet(
                      context,
                      name: stop.name,
                      address: stop.address,
                      category: stop.category,
                      latitude: stop.latLng.latitude,
                      longitude: stop.latLng.longitude,
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              stop.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.neutralScale[600],
                              ),
                            ),
                          ),
                          Text(
                            stop.time,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryScale[500],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stop.address,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.neutralScale[300]),
                      ),
                    ],
                  ),
                ),
                if (stop.transport != null) ...[
                  const SizedBox(height: 14),
                  _buildTransportCard(stop.transport!),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 이동수단 카드 (글라스 효과 + TransportTheme 색상) ──────────

  Widget _buildTransportCard(_TransportInfo transport) {
    final theme = TransportTheme.byLabel(transport.label);
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: const Alignment(-0.54, -0.84),
              end:   const Alignment( 0.54,  0.84),
              colors: [
                Colors.white.withValues(alpha: 0.26),
                Colors.white.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.65),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.iconColor.withValues(alpha: 0.10),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.iconBg,
                ),
                child: Center(
                  child: AppIcon(theme.svgPath, size: 18, color: theme.iconColor),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                transport.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.neutralScale[600],
                ),
              ),
              const Spacer(),
              Text(
                '${transport.duration} · ${transport.distance}',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.neutralScale[400],
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  // ── 일정 시작하기 버튼 (showBackButton=true) ─────────────────

  Widget _buildStartButton(BuildContext context) {
    return Padding(
      // 저장 버튼이 있던 자리를 그대로 잇는다. 아래 여백은 형제인
      // '재탐색하러 가기' 버튼이 이미 갖고 있어 여기서 또 주면 겹친다.
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryScale[400]!,
                AppColors.primaryScale[600]!,
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ElevatedButton(
            onPressed: () =>
                context.push('/navigation', extra: _startTarget),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              '일정 시작하기',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 하단 버튼 ────────────────────────────────────────────────

  Widget _buildBottomButtons(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_isSaved)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
            child: NextButton(
              label: '일정 저장하기',
              onPressed: () {
                if (isAuthenticated.value) {
                  _showSaveBottomSheet(context);
                } else {
                  _showLoginDialog(context);
                }
              },
            ),
          )
        // 저장을 마치면 저장 버튼 자리를 시작 버튼이 잇는다. 이게 없으면
        // 저장한 사용자에게 남는 선택지가 '재탐색' 하나뿐이라, 방금 만든
        // 일정을 시작하려면 저장 탭으로 돌아가 다시 열어야 했다.
        else if (_startTarget != null)
          _buildStartButton(context),
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: PrevButton(
            onPressed: () => context.go('/trip/search'),
            label: _isSaved ? '← 재탐색하러 가기' : '추가 탐색하기',
          ),
        ),
      ],
    );
  }

  // ── 로그인 유도 다이얼로그 ───────────────────────────────────

  void _showLoginDialog(BuildContext context) {
    if (widget.response != null) {
      TripRepository.instance.setPendingTrip(widget.response!);
    }
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '일정을 저장하려면\n로그인이 필요해요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutralScale[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              KakaoLoginButton(onPressed: () {
                Navigator.of(ctx).pop();
                // TODO: 카카오 로그인 연동
              }),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.push('/auth/email');
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.neutralScale[200]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  child: Text(
                    '이메일로 계속하기',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                      color: AppColors.neutralScale[500],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.push('/signup/step1');
                },
                child: Text(
                  '회원가입',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.neutralScale[300],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSavedTripBottomButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.tripAccentPurple, AppColors.tripAccentPurpleEnd],
            ),
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: AppColors.tripAccentPurpleEnd.withValues(alpha: 0.25),
                blurRadius: 28.8,
                offset: const Offset(0, 24),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: () => context.push('/navigation', extra: _startTarget),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
            ),
            child: const Text(
              '일정 시작하기',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 저장 완료 다이얼로그 ─────────────────────────────────────

  void _showSavedDialog(BuildContext context, String name) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.neutralScale[600],
                    height: 1.5,
                  ),
                  children: [
                    TextSpan(
                      text: '"$name"',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryScale[500],
                      ),
                    ),
                    const TextSpan(
                      text: '\n일정이 저장되었어요!',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      AppColors.gradientScale[200]!,
                      AppColors.gradientScale[600]!,
                    ]),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      // 목록이 아니라 일정 선택으로 보낸다. 목록으로 보내면
                      // 방을 만드는 화면을 사용자가 다시 찾아 들어가야 한다.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (context.mounted) context.go('/chat/new');
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    child: const Text(
                      '대화방 생성하기',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    TripRepository.instance.requestedTab.value = 0;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (context.mounted) context.go('/saved');
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.neutralScale[200]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  child: Text(
                    '닫기',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutralScale[500],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  /// 저장한 일정을 서버에도 남긴다.
  ///
  /// 서버에 남아야 다른 기기에서 열리고, 이 일정으로 대화방을 만들 수 있다
  /// (대화방은 자기가 소유한 일정에만 만들 수 있다).
  ///
  /// 방금 만든 일정이 아니거나 로그인하지 않았으면 건너뛴다 — 토큰 없이
  /// 보내면 주인 없는 일정으로 남아 다시 꺼내 볼 수 없다.
  /// 반환: 저장된 일정 식별자. 저장하지 못했으면 null.
  /// 방금 저장한 일정을 시작 화면이 받는 형태로 접는다.
  ///
  /// 서버에서 다시 받아 오지 않는 이유는, 방금 화면에 그린 그 방문지가 이미
  /// 손에 있고 상세 조회는 도로 경로를 다시 받아 오느라 왕복이 길기 때문이다.
  /// 서버에서 다시 열면 그때 상세 조회가 돈다.
  SavedTrip? _asSavedTrip(
      int scheduleId, String name, DateTime start, DateTime end) {
    final response = widget.response;
    if (response == null) return null;
    return SavedTrip(
      scheduleId: scheduleId,
      name: name,
      route: response.stops.map((s) => s.name).join(' → '),
      savedAt: DateTime.now(),
      tripStartDate: start,
      tripEndDate: end,
      stops: response.stops,
      totalDurationMinutes: response.totalDurationMinutes,
    );
  }

  Future<int?> _persistToServer(
      String name, DateTime start, DateTime end) async {
    final response = widget.response;
    final plan = TripRepository.instance.lastPlan;
    if (response == null || plan == null) return null;
    if (!isAuthenticated.value) {
      _toast('로그인해야 일정을 저장할 수 있어요.');
      return null;
    }
    try {
      return await ScheduleApiService.instance.save(
        jobId: response.tripId,
        title: name,
        dateStart: start,
        dateEnd: end,
        transport: plan.transport,
        activeStartHour: plan.activeStartHour,
        activeEndHour: plan.activeEndHour,
      );
    } on ApiException catch (e) {
      _toast('저장하지 못했어요: ${e.message}');
      return null;
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ── 저장 바텀시트 ─────────────────────────────────────────────

  void _showSaveBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (sheetContext) => _SaveBottomSheet(
        onSaved: (name) async {
          final start = widget.startDate ?? DateTime.now();
          final end = widget.endDate ?? start;
          // 저장 탭이 서버 목록을 보므로, 서버에 남은 뒤에야 저장됐다고 말한다.
          // 순서를 뒤집으면 실패한 저장을 성공으로 알리게 된다.
          final scheduleId = await _persistToServer(name, start, end);
          if (!mounted || scheduleId == null) return;
          setState(() {
            _isSaved = true;
            _startTarget = _asSavedTrip(scheduleId, name, start, end);
          });
          TripRepository.instance.markSavedChanged();
          _showSavedDialog(this.context, name);
        },
      ),
    );
  }
}

// ─── 저장 바텀시트 위젯 ───────────────────────────────────────

class _SaveBottomSheet extends StatefulWidget {
  const _SaveBottomSheet({required this.onSaved});
  final void Function(String name) onSaved;

  @override
  State<_SaveBottomSheet> createState() => _SaveBottomSheetState();
}

class _SaveBottomSheetState extends State<_SaveBottomSheet> {
  final _controller = TextEditingController();
  String? _errorText;

  void _onChanged(String value) {
    setState(() {
      if (value.isEmpty) {
        _errorText = null;
      } else if (value.length > 20) {
        _errorText = '20자 이하로 입력해주세요.';
      } else {
        _errorText = null;
      }
    });
  }

  bool get _canSave =>
      _controller.text.isNotEmpty &&
      _controller.text.length <= 20 &&
      _errorText == null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 14, 24,
        keyboardHeight > 0 ? keyboardHeight + 16 : bottomPadding + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 드래그 핸들
          Center(
            child: Container(
              width: 44, height: 5,
              decoration: BoxDecoration(
                color: AppColors.neutralScale[200],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            '✏️ 일정 이름을 정해주세요.',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.neutralScale[600],
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '지정된 여행 목록에 표시될 이름이에요!',
            style: TextStyle(fontSize: 14, color: AppColors.neutralScale[300]),
          ),
          const SizedBox(height: 32),
          _buildNameField(),
          const SizedBox(height: 32),
          _buildSaveButton(context),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AppTextField(
          controller: _controller,
          hintText: '일정 이름',
          onChanged: _onChanged,
          maxLength: 20,
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              height: 16,
              child: _errorText != null
                  ? Text(
                      _errorText!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.error,
                      ),
                    )
                  : null,
            ),
            Text(
              '${_controller.text.length} / 20',
              style: TextStyle(fontSize: 12, color: AppColors.neutralScale[300]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    final bool canSave = _canSave;
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: canSave
                ? [AppColors.secondaryScale[900]!, AppColors.secondaryScale[500]!]
                : [AppColors.neutralScale[100]!, AppColors.neutralScale[100]!],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: ElevatedButton(
          onPressed: canSave
              ? () {
                  Navigator.pop(context);
                  widget.onSaved(_controller.text);
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            overlayColor: Colors.white.withValues(alpha: 0.15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: Text(
            '일정 저장하기',
            style: TextStyle(
              color: canSave ? Colors.white : AppColors.neutralScale[300],
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 데이터 모델 ──────────────────────────────────────────────

class _ScheduleStop {
  final int day;
  final String name;
  final String address;
  final String time;
  final LatLng latLng;
  final _TransportInfo? transport;

  /// 장소 분류. 상세 시트의 분류 칩에 쓴다. 서버가 못 채우면 비어 있고,
  /// 그때는 칩이 아예 나오지 않는다.
  final String? category;

  /// 서버가 부여한 장소 식별자. 이 장소를 지목해 다시 요청할 때 쓴다.
  final int? placeId;

  const _ScheduleStop({
    required this.day,
    required this.name,
    required this.address,
    required this.time,
    required this.latLng,
    required this.transport,
    this.category,
    this.placeId,
  });
}

class _TransportInfo {
  final String label;
  final String duration;
  final String distance;

  /// 이 stop 에서 다음 stop 까지의 도로 추종 경로. 없으면 지도는 직선으로 잇는다.
  final List<LatLng>? path;

  const _TransportInfo({
    required this.label,
    required this.duration,
    required this.distance,
    this.path,
  });
}
