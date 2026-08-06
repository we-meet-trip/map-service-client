import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/next_button.dart';
import '../../../common/widgets/prev_button.dart';
import '../../../core/naver_map/naver_map_adapter.dart';
import '../models/place.dart';
import '../providers/place_explore_provider.dart';
import '../widgets/place_pin.dart';
import '../widgets/place_bottom_sheet.dart';
import '../widgets/glass_icon_button.dart';
import '../../trip/widgets/trip_step_header.dart';

const _kInitialCamera = NCameraPosition(
  target: NLatLng(37.5666, 126.9784),
  zoom: 12.0,
);

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
  NaverMapController? _mapController;
  bool _markersInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PlaceExploreProvider>().loadPlaces();
    });
  }

  Future<void> _tryInitMarkers() async {
    final provider = context.read<PlaceExploreProvider>();
    if (_mapController == null || provider.places.isEmpty || _markersInitialized) return;
    _markersInitialized = true;
    await _initMarkers(_mapController!, provider.places);
  }

  Future<void> _initMarkers(NaverMapController controller, List<Place> places) async {
    for (int i = 0; i < places.length; i++) {
      if (!mounted) return;
      final place = places[i];
      final icon = await NOverlayImage.fromWidget(
        widget: PlacePin(number: i + 1),
        size: const Size(32, 40),
        context: context,
      );
      final marker = NMarker(
        id: place.id,
        position: NLatLng(place.latitude, place.longitude),
        icon: icon,
      );
      marker.setOnTapListener((_) {
        if (mounted) _showPlaceSheet(place);
      });
      await controller.addOverlay(marker);
    }
  }

  Future<void> _showPlaceSheet(Place place) async {
    final provider = context.read<PlaceExploreProvider>();
    final detail = await provider.loadDetail(place.id);
    if (detail == null || !mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => PlaceBottomSheet(
        detail: detail,
        isAdded: provider.selectedIds.contains(place.id),
        onToggle: () => context.read<PlaceExploreProvider>().togglePlace(place.id),
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
          child: NaverMap(
            options: const NaverMapViewOptions(
              initialCameraPosition: _kInitialCamera,
              scrollGesturesEnable: true,
              zoomGesturesEnable: true,
              rotationGesturesEnable: false,
              mapType: NMapType.basic,
            ),
            onMapReady: (controller) {
              _mapController = controller;
              _tryInitMarkers();
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
                  onPressed: () =>
                      _mapController?.updateCamera(NCameraUpdate.zoomIn()),
                ),
                const SizedBox(height: 8),
                GlassIconButton(
                  icon: Icons.remove,
                  onPressed: () =>
                      _mapController?.updateCamera(NCameraUpdate.zoomOut()),
                ),
              ],
            ),
          ),
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
      padding: EdgeInsets.fromLTRB(24, 40, 24, bottomPad + 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NextButton(
            onPressed: count > 0 ? widget.onNext : null,
          ),
          const SizedBox(height: 10),
          PrevButton(onPressed: widget.onPrev),
        ],
      ),
    );
  }

  Widget _buildSelectionBadge(int count) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
