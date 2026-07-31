import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/naver_map/naver_map_adapter.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/theme/app_icons.dart';
import '../widgets/transport_theme.dart';
import '../../../common/widgets/next_button.dart';
import '../../../common/widgets/prev_button.dart';
import '../../../common/widgets/app_confirm_dialog.dart';
import '../../../core/state/trip_repository.dart';
import '../../../common/widgets/text_field.dart';
import '../../../core/api/trip_api_service.dart';
import '../../../core/router/app_router.dart';
import '../../auth/widgets/kakao_login_button.dart';
import '../../../common/widgets/draggable_vision_button.dart';

class TripCreatedScreen extends StatefulWidget {
  const TripCreatedScreen({
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
  State<TripCreatedScreen> createState() => _TripCreatedScreenState();
}

class _TripCreatedScreenState extends State<TripCreatedScreen> {
  late bool _isSaved = widget.showBackButton;
  bool _shouldAutoSave = false;

  late final List<_ScheduleStop> _stops;
  late final int _totalDurationMinutes;
  late final List<int> _days;
  late int _selectedDay;
  NaverMapController? _mapController;

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
      // 저장된 일정 보기 등 response 없을 때 placeholder
      _stops = _placeholder;
      _totalDurationMinutes = 25;
    }
    // 로그인 후 복귀 시 자동으로 저장 바텀시트 열기
    if (TripRepository.instance.autoSaveOnNext && isAuthenticated.value) {
      TripRepository.instance.autoSaveOnNext = false;
      _shouldAutoSave = true;
    }
  }

  List<_ScheduleStop> get _selectedDayStops =>
      _stops.where((s) => s.day == _selectedDay).toList();

  static _ScheduleStop _fromApiStop(TripStop s) => _ScheduleStop(
        day: s.day,
        name: s.name,
        address: s.address,
        time: s.time,
        latLng: NLatLng(s.latitude, s.longitude),
        transport: s.transportToNext != null
            ? _TransportInfo(
                label: s.transportToNext!.label,
                duration: '${s.transportToNext!.durationMinutes}분',
                distance: '${s.transportToNext!.distanceKm}km',
              )
            : null,
      );

  static final List<_ScheduleStop> _placeholder = [
    _ScheduleStop(
      day: 1,
      name: '속초 버스 터미널',
      address: '강원특별자치도 속초시 중앙로 96',
      time: '09:00',
      latLng: const NLatLng(38.2052, 128.5917),
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
      latLng: const NLatLng(38.2014, 128.6008),
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
      latLng: const NLatLng(38.2089, 128.5875),
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
    return Stack(
      children: [
        _buildBody(context),
        const DraggableVisionButton(),
      ],
    );
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

  // ── 지도 영역 ────────────────────────────────────────────────
  // (Stack의 두 번째 자식 DraggableVisionButton은 build()에서 추가됨)

  Widget _buildMapArea() {
    return SizedBox(
      width: double.infinity,
      height: 280,
      child: NaverMap(
        options: NaverMapViewOptions(
          initialCameraPosition: NCameraPosition(
            target: _selectedDayStops.isNotEmpty
                ? _selectedDayStops.first.latLng
                : _stops.first.latLng,
            zoom: 14,
          ),
          scrollGesturesEnable: true,
          zoomGesturesEnable: true,
          rotationGesturesEnable: false,
          mapType: NMapType.basic,
        ),
        onMapReady: _onMapReady,
      ),
    );
  }

  Future<void> _onMapTapped(NLatLng latLng) async {
    final controller = _mapController;
    if (controller == null) return;

    // 현재 GPS 위치 가져오기
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final locationOverlay = controller.getLocationOverlay();
      locationOverlay.setIsVisible(true);
      locationOverlay.setPosition(NLatLng(position.latitude, position.longitude));
      locationOverlay.setBearing(position.heading);
    } catch (_) {
      // 위치 권한 없거나 실패 시 무시
    }
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

  Future<void> _onMapReady(NaverMapController controller) async {
    _mapController = controller;
    await _renderDayOverlays(controller);
  }

  Future<void> _renderDayOverlays(NaverMapController controller) async {
    final stops = _selectedDayStops;
    if (stops.isEmpty) return;

    await controller.clearOverlays();

    // 번호 마커 추가
    for (int i = 0; i < stops.length; i++) {
      if (!mounted) return;
      final icon = await NOverlayImage.fromWidget(
        widget: _buildNumberMarker('${i + 1}'),
        size: const Size(36, 36),
        context: context,
      );
      await controller.addOverlay(NMarker(
        id: 'stop_$i',
        position: stops[i].latLng,
        icon: icon,
      ));
    }

    // 경로 폴리라인 추가
    await controller.addOverlay(NPolylineOverlay(
      id: 'route',
      coords: stops.map((s) => s.latLng).toList(),
      color: AppColors.primaryScale[400]!,
      width: 4,
    ));

    // 해당 일차 정류장이 모두 보이도록 fitBounds
    final lats = stops.map((s) => s.latLng.latitude);
    final lngs = stops.map((s) => s.latLng.longitude);
    final bounds = NLatLngBounds(
      southWest: NLatLng(lats.reduce(min), lngs.reduce(min)),
      northEast: NLatLng(lats.reduce(max), lngs.reduce(max)),
    );
    controller.updateCamera(
      NCameraUpdate.fitBounds(bounds, padding: const EdgeInsets.all(56))
        ..setAnimation(
          animation: NCameraAnimation.fly,
          duration: const Duration(milliseconds: 800),
        ),
    );
  }

  Widget _buildNumberMarker(String number) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primaryScale[400]!, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.neutralScale[600]!.withAlpha(0x26),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          number,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryScale[500],
          ),
        ),
      ),
    );
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      stop.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.neutralScale[600],
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
                  style: TextStyle(fontSize: 12, color: AppColors.neutralScale[300]),
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
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
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
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.paddingOf(context).bottom + 16,
      ),
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
                context.push('/navigation', extra: widget.savedTrip),
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
          ),
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
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('즐거운 여행 되세요!')),
            ),
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
      builder: (ctx) => AppConfirmDialog(
        content: RichText(
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
        cancelLabel: '닫기',
        confirmLabel: '보러가기',
        onConfirm: () {
          Navigator.of(ctx).pop();
          TripRepository.instance.requestedTab.value = 0;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.go('/saved');
            }
          });
        },
      ),
    );
  }

  // ── 저장 바텀시트 ─────────────────────────────────────────────

  void _showSaveBottomSheet(BuildContext context) {
    final route = _stops.map((s) => s.name).join(' → ');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (sheetContext) => _SaveBottomSheet(
        onSaved: (name) {
          TripRepository.instance.addTrip(SavedTrip(
            name: name,
            route: route,
            savedAt: DateTime.now(),
            tripStartDate: widget.startDate ?? DateTime.now(),
            tripEndDate: widget.endDate ?? DateTime.now(),
            stops: widget.response?.stops ?? const [],
            totalDurationMinutes: widget.response?.totalDurationMinutes ?? _totalDurationMinutes,
          ));
          setState(() => _isSaved = true);
          _showSavedDialog(context, name);
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
  final NLatLng latLng;
  final _TransportInfo? transport;

  const _ScheduleStop({
    required this.day,
    required this.name,
    required this.address,
    required this.time,
    required this.latLng,
    required this.transport,
  });
}

class _TransportInfo {
  final String label;
  final String duration;
  final String distance;

  const _TransportInfo({
    required this.label,
    required this.duration,
    required this.distance,
  });
}
