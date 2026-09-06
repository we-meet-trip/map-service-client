import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/app_loading_screen.dart';
import '../../../common/widgets/next_button.dart';
import '../../../common/widgets/prev_button.dart';
import '../../../core/api/trip_api_service.dart';
import '../../../core/state/trip_repository.dart';
import 'google_trip_created_screen.dart';

/// 추천받은 장소를 지도 핀으로 띄우고 골라 동선을 다시 만드는 화면.
///
/// 여기서 다루는 장소는 **방금 추천받은 장소뿐**이다. 새로 찾지 않는다 —
/// 이미 만들어진 일정에서 마음에 드는 곳만 남기는 것이 이 화면의 일이다.
///
/// 고르고 나면 동선만 다시 만들어 일정 결과 화면을 그대로 재사용한다.
/// 장소가 이미 정해져 있어 서버는 예산·테마를 받지 않는다.
class GooglePlacePickScreen extends StatefulWidget {
  const GooglePlacePickScreen({super.key});

  @override
  State<GooglePlacePickScreen> createState() => _GooglePlacePickScreenState();
}

class _GooglePlacePickScreenState extends State<GooglePlacePickScreen> {
  /// 서버가 받는 장소 수 범위. 이보다 적거나 많으면 요청이 거절되므로
  /// 화면에서 먼저 막는다.
  static const _minPlaces = 2;
  static const _maxPlaces = 10;

  GoogleMapController? _mapController;
  Set<Marker> _markers = const {};

  /// 고른 장소의 위치(원본 목록 기준). 이름이 겹칠 수 있어 위치로 센다.
  final Set<int> _picked = {};

  bool _isLoading = false;
  Future<void>? _routeFuture;
  TripGenerateResponse? _result;

  TripPlanContext? get _plan => TripRepository.instance.lastPlan;

  List<TripStop> get _stops => _plan?.stops ?? const [];

  @override
  void initState() {
    super.initState();
    // 처음에는 전부 골라 둔다. 빼고 싶은 곳만 눌러 해제하는 흐름이
    // 하나씩 채우는 것보다 손이 덜 간다.
    _picked.addAll(List.generate(_stops.length, (i) => i));
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  bool get _canProceed =>
      _picked.length >= _minPlaces && _picked.length <= _maxPlaces;

  void _toggle(int index) {
    setState(() {
      if (!_picked.remove(index)) {
        _picked.add(index);
      }
    });
    _renderMarkers();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _renderMarkers();
  }

  /// 고른 장소는 진하게, 뺀 장소는 흐리게 그린다.
  ///
  /// 마커를 다시 그릴 때마다 전부 지우고 새로 얹는다.
  ///
  /// 한 번에 한 벌만 그린다. 이 화면은 핀을 누를 때마다 다시 그리는 데다
  /// 지도를 다시 만들면 준비 통지로도 들어와, 두 벌이 겹치기 가장 쉽다.
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
      if (previous != null) await previous;
      await _renderMarkersPass(pass);
    } finally {
      done.complete();
      if (identical(_renderInFlight, done.future)) _renderInFlight = null;
    }
  }

  Future<void> _renderMarkersPass(int pass) async {
    final stops = _stops;
    if (stops.isEmpty || !mounted) return;
    bool stale() => !mounted || pass != _renderPass;

    final markers = <Marker>{};
    for (int i = 0; i < stops.length; i++) {
      if (stale()) return;
      final icon = await _makePinMarker('${i + 1}', _picked.contains(i));
      if (stale()) return;
      final index = i;
      markers.add(Marker(
        markerId: MarkerId('pick_$i'),
        position: LatLng(stops[i].latitude, stops[i].longitude),
        icon: icon,
        onTap: () => _toggle(index),
        infoWindow: InfoWindow(title: stops[i].name),
      ));
    }
    if (stale()) return;

    setState(() => _markers = markers);

    final lats = stops.map((s) => s.latitude);
    final lngs = stops.map((s) => s.longitude);
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(lats.reduce(min), lngs.reduce(min)),
          northeast: LatLng(lats.reduce(max), lngs.reduce(max)),
        ),
        56.0,
      ),
    );
  }

  Future<BitmapDescriptor> _makePinMarker(String number, bool picked) async {
    const size = 76.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final bgColor = picked ? AppColors.primaryScale[500]! : Colors.white;
    final borderColor =
        picked ? AppColors.primaryScale[500]! : AppColors.neutralScale[200]!;
    final textColor =
        picked ? Colors.white : AppColors.neutralScale[300]!;
    canvas.drawCircle(
        Offset(size / 2, size / 2 + 2),
        size / 2 - 4,
        Paint()
          ..color = Colors.black.withAlpha(0x26)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(
        Offset(size / 2, size / 2), size / 2 - 4, Paint()..color = bgColor);
    canvas.drawCircle(
        Offset(size / 2, size / 2),
        size / 2 - 4,
        Paint()
          ..color = borderColor
          ..strokeWidth = 4.0
          ..style = PaintingStyle.stroke);
    final tp = TextPainter(
      text: TextSpan(
          text: number,
          style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: textColor)),
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

  Widget _buildPin(String number, bool picked) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: picked ? AppColors.primaryScale[500] : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: picked
              ? AppColors.primaryScale[500]!
              : AppColors.neutralScale[200]!,
          width: 2,
        ),
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
            color: picked ? Colors.white : AppColors.neutralScale[300],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final plan = _plan;
    if (plan == null || !_canProceed) return;
    final picked = _picked.toList()..sort();
    final places = picked
        .map((i) => SelectedPlace(
              name: _stops[i].name,
              address: _stops[i].address,
              latitude: _stops[i].latitude,
              longitude: _stops[i].longitude,
              day: _stops[i].day,
            ))
        .toList();
    final request = TripRouteRequest(
      startDate: plan.startDate,
      endDate: plan.endDate,
      activeStartHour: plan.activeStartHour,
      activeEndHour: plan.activeEndHour,
      transport: plan.transport,
      province: plan.province,
      city: plan.city,
      places: places,
    );
    setState(() {
      _isLoading = true;
      _routeFuture = TripApiService.instance
          .routeTrip(request)
          .then((res) => _result = res);
    });
  }

  void _onLoadComplete() {
    final result = _result;
    if (result == null) return;
    // 다시 만든 일정도 이후 재탐색의 출발점이 되도록 조건을 갱신해 둔다.
    final plan = _plan;
    if (plan != null) {
      TripRepository.instance.setLastPlan(TripPlanContext(
        startDate: plan.startDate,
        endDate: plan.endDate,
        activeStartHour: plan.activeStartHour,
        activeEndHour: plan.activeEndHour,
        transport: plan.transport,
        province: plan.province,
        city: plan.city,
        stops: result.stops,
      ));
    }
    setState(() {
      _isLoading = false;
      _routeFuture = null;
    });
  }

  void _onLoadError(Object error) {
    final message = error is TripApiException
        ? error.message
        : '동선을 다시 만들지 못했어요. 잠시 후 다시 시도해주세요.';
    setState(() {
      _isLoading = false;
      _routeFuture = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return AppLoadingScreen(
        future: _routeFuture,
        minDuration: const Duration(seconds: 2),
        onComplete: _onLoadComplete,
        onError: _onLoadError,
      );
    }
    // 다시 만든 일정은 생성 직후와 같은 화면으로 보여 준다.
    final result = _result;
    if (result != null) {
      return GoogleTripCreatedScreen(response: result);
    }
    if (_stops.isEmpty) {
      return _buildEmpty();
    }
    return Column(
      children: [
        _buildMap(),
        Expanded(child: _buildList()),
        _buildFooter(),
      ],
    );
  }

  /// 고를 장소가 없을 때. 일정을 먼저 만들어야 한다.
  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.place_outlined,
              size: 48, color: AppColors.neutralScale[200]),
          const SizedBox(height: 16),
          Text(
            '고를 수 있는 추천 장소가 없어요.\n일정을 먼저 만들어 주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, color: AppColors.neutralScale[400], height: 1.5),
          ),
          const SizedBox(height: 24),
          PrevButton(
            onPressed: () => context.go('/trip'),
            label: '← 여행 계획으로',
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return SizedBox(
      height: 280,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(_stops.first.latitude, _stops.first.longitude),
          zoom: 12,
        ),
        markers: _markers,
        onMapCreated: _onMapCreated,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        scrollGesturesEnabled: true,
        zoomGesturesEnabled: true,
        rotateGesturesEnabled: false,
      ),
    );
  }

  Widget _buildList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      children: [
        Text(
          '함께 갈 장소를 골라주세요',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.neutralScale[600],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$_minPlaces~$_maxPlaces곳까지 고를 수 있어요. '
          '고른 곳만으로 동선을 다시 짜 드려요.',
          style: TextStyle(fontSize: 13, color: AppColors.neutralScale[300]),
        ),
        const SizedBox(height: 20),
        for (int i = 0; i < _stops.length; i++) _buildRow(i, _stops[i]),
      ],
    );
  }

  Widget _buildRow(int index, TripStop stop) {
    final picked = _picked.contains(index);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _toggle(index),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: picked ? AppColors.primaryScale[50] : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: picked
                  ? AppColors.primaryScale[300]!
                  : AppColors.neutralScale[100]!,
            ),
          ),
          child: Row(
            children: [
              _buildPin('${index + 1}', picked),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${stop.day}일차 · ${stop.address}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: AppColors.neutralScale[300]),
                    ),
                  ],
                ),
              ),
              Icon(
                picked
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                color: picked
                    ? AppColors.primaryScale[500]
                    : AppColors.neutralScale[200],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    // 고른 수가 범위를 벗어나면 왜 진행할 수 없는지 그 자리에서 알려 준다.
    final String? hint = _picked.length < _minPlaces
        ? '$_minPlaces곳 이상 골라주세요.'
        : _picked.length > _maxPlaces
            ? '$_maxPlaces곳까지만 고를 수 있어요.'
            : null;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hint != null) ...[
            Text(
              hint,
              style: TextStyle(
                  fontSize: 12, color: AppColors.secondaryScale[500]),
            ),
            const SizedBox(height: 8),
          ],
          NextButton(
            label: '고른 ${_picked.length}곳으로 동선 만들기  →',
            onPressed: _canProceed ? _submit : null,
          ),
          const SizedBox(height: 10),
          PrevButton(
            onPressed: () => context.go('/trip/search'),
            label: '← 다시 고르기',
          ),
        ],
      ),
    );
  }
}
