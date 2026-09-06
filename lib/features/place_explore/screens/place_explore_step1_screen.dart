import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/next_button.dart';
import '../../../common/widgets/prev_button.dart';
import '../models/place.dart';
import '../providers/place_explore_provider.dart';
import '../widgets/place_bottom_sheet.dart';
import '../widgets/glass_icon_button.dart';
import '../../trip/widgets/trip_step_header.dart';

const _kInitialTarget = LatLng(37.5666, 126.9784);

/// 안내 글이 덮는 위쪽 높이.
const _headerInset = 190.0;

/// 버튼이 덮는 아래쪽 높이.
const _buttonsInset = 190.0;

class PlaceExploreStep1Screen extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onPrev;

  const PlaceExploreStep1Screen({
    super.key,
    required this.onNext,
    required this.onPrev,
  });

  @override
  State<PlaceExploreStep1Screen> createState() =>
      _PlaceExploreStep1ScreenState();
}

class _PlaceExploreStep1ScreenState extends State<PlaceExploreStep1Screen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = const {};
  bool _markersInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PlaceExploreProvider>().loadPlaces();
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  int _renderPass = 0;
  Future<void>? _renderInFlight;

  Future<void> _tryInitMarkers() async {
    final provider = context.read<PlaceExploreProvider>();
    if (_mapController == null || provider.places.isEmpty || _markersInitialized) return;
    _markersInitialized = true;
    final controller = _mapController!;
    final places = provider.places;

    final pass = ++_renderPass;
    final previous = _renderInFlight;
    final done = Completer<void>();
    _renderInFlight = done.future;
    try {
      if (previous != null) await previous;
      if (!mounted || pass != _renderPass || _mapController != controller) return;
      await _initMarkers(places, pass, controller);
      if (!mounted || pass != _renderPass || _mapController != controller) return;
      _fitCamera(places, controller);
    } finally {
      done.complete();
      if (identical(_renderInFlight, done.future)) _renderInFlight = null;
    }
  }

  void _fitCamera(List<Place> places, GoogleMapController controller) {
    if (places.isEmpty) return;

    var minLat = places.first.latitude;
    var maxLat = places.first.latitude;
    var minLng = places.first.longitude;
    var maxLng = places.first.longitude;
    for (final place in places) {
      if (place.latitude < minLat) minLat = place.latitude;
      if (place.latitude > maxLat) maxLat = place.latitude;
      if (place.longitude < minLng) minLng = place.longitude;
      if (place.longitude > maxLng) maxLng = place.longitude;
    }

    const minSpan = 1e-6;
    if (maxLat - minLat < minSpan && maxLng - minLng < minSpan) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(minLat, minLng), 14),
      );
      return;
    }

    final media = MediaQuery.of(context);
    final limit = media.size.height * 0.25;
    final top = math.min(media.padding.top + _headerInset, limit);
    final bottom = math.min(media.padding.bottom + _buttonsInset, limit);

    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        math.max(top, bottom) + 60,
      ),
    );
  }

  Future<void> _initMarkers(
      List<Place> places, int pass, GoogleMapController controller) async {
    bool stale() =>
        !mounted || pass != _renderPass || _mapController != controller;

    final markers = <Marker>{};
    for (int i = 0; i < places.length; i++) {
      if (stale()) return;
      final place = places[i];
      final provider = context.read<PlaceExploreProvider>();
      final isPicked = provider.selectedIds.contains(place.id);
      final icon = await _makePinMarker(i + 1, isPicked);
      if (stale()) return;
      markers.add(Marker(
        markerId: MarkerId(place.id),
        position: LatLng(place.latitude, place.longitude),
        icon: icon,
        onTap: () => _showPlaceSheet(place),
        infoWindow: InfoWindow(title: place.name),
      ));
    }
    if (stale()) return;
    setState(() => _markers = markers);
  }

  Future<BitmapDescriptor> _makePinMarker(int number, bool picked) async {
    const size = 56.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final bgColor = picked ? AppColors.primaryScale[500]! : Colors.white;
    final borderColor =
        picked ? AppColors.primaryScale[500]! : AppColors.neutralScale[200]!;
    final textColor = picked ? Colors.white : AppColors.neutralScale[400]!;

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
          ..strokeWidth = 3.0
          ..style = PaintingStyle.stroke);
    final tp = TextPainter(
      text: TextSpan(
          text: '$number',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: textColor)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));
    final image =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  // 장소 선택 상태가 바뀌면 해당 마커만 다시 그린다.
  Future<void> _refreshMarker(Place place, int index) async {
    final provider = context.read<PlaceExploreProvider>();
    final isPicked = provider.selectedIds.contains(place.id);
    final icon = await _makePinMarker(index + 1, isPicked);
    if (!mounted) return;
    setState(() {
      _markers = {
        for (final m in _markers)
          if (m.markerId.value == place.id)
            m.copyWith(iconParam: icon)
          else
            m,
      };
    });
  }

  Future<void> _showPlaceSheet(Place place) async {
    final provider = context.read<PlaceExploreProvider>();
    final detail = await provider.loadDetail(place.id);
    if (detail == null || !mounted) return;
    final index = provider.places.indexWhere((p) => p.id == place.id);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => PlaceBottomSheet(
        detail: detail,
        isAdded: provider.selectedIds.contains(place.id),
        onToggle: () async {
          provider.togglePlace(place.id);
          if (index >= 0) await _refreshMarker(place, index);
        },
        latitude: place.latitude,
        longitude: place.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlaceExploreProvider>();
    final selectedIds = provider.selectedIds;
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    if (provider.status == PlaceExploreStatus.success && !_markersInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tryInitMarkers();
      });
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _kInitialTarget,
              zoom: 12,
            ),
            markers: _markers,
            onMapCreated: (controller) {
              if (!identical(_mapController, controller)) {
                _markersInitialized = false;
              }
              _mapController = controller;
              _tryInitMarkers();
            },
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
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildHeader(topPad),
        ),
        Positioned(
          right: 14,
          top: 0,
          bottom: 0,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlassIconButton(
                  icon: Icons.add,
                  onPressed: () => _mapController
                      ?.animateCamera(CameraUpdate.zoomIn()),
                ),
                const SizedBox(height: 8),
                GlassIconButton(
                  icon: Icons.remove,
                  onPressed: () => _mapController
                      ?.animateCamera(CameraUpdate.zoomOut()),
                ),
              ],
            ),
          ),
        ),
        if (provider.status == PlaceExploreStatus.error)
          Positioned(
            left: 24,
            right: 24,
            top: 0,
            bottom: 0,
            child: Center(child: _buildEmptyPlanNotice()),
          ),
        if (selectedIds.isNotEmpty)
          Positioned(
            left: 14,
            top: topPad + 160,
            child: _buildSelectionBadge(selectedIds.length),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildButtons(bottomPad, selectedIds.length),
        ),
      ],
    );
  }

  Widget _buildHeader(double topPad) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.background,
            AppColors.background,
            AppColors.background.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.72, 1.0],
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, topPad + 20, 24, 40),
      child: const TripStepHeader(
        step: 1,
        totalSteps: 2,
        title: '어디로 떠나볼까요?',
        subtitle: '원하는 장소 최소 3곳을 선택해주세요.',
      ),
    );
  }

  Widget _buildButtons(double bottomPad, int count) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            AppColors.background,
            AppColors.background.withValues(alpha: 0.0),
          ],
          stops: const [0.10, 1.0],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(24, 40, 24, 10 + bottomPad),
            child: NextButton(
              onPressed: count > 0 ? widget.onNext : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: PrevButton(onPressed: widget.onPrev),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlanNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.neutralScale[600]!.withAlpha(0x1A),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        '생성된 일정이 없어요.\n일정을 먼저 만들어주세요.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.neutralScale[600],
        ),
      ),
    );
  }

  Widget _buildSelectionBadge(int count) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryScale[500]!.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count곳 선택됨',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
