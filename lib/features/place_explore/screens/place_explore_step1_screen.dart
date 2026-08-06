import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';
import '../../../core/naver_map/naver_map_adapter.dart';
import '../models/place.dart';
import '../widgets/place_pin.dart';
import '../widgets/place_bottom_sheet.dart';
import '../../trip/widgets/trip_step_header.dart';
import '../../trip/widgets/trip_step_scaffold.dart';

const _kInitialCamera = NCameraPosition(
  target: NLatLng(37.5666, 126.9784),
  zoom: 12.0,
);

class PlaceExploreStep1Screen extends StatefulWidget {
  final List<Place> places;
  final VoidCallback onNext;
  final VoidCallback onPrev;

  const PlaceExploreStep1Screen({
    super.key,
    required this.places,
    required this.onNext,
    required this.onPrev,
  });

  @override
  State<PlaceExploreStep1Screen> createState() =>
      _PlaceExploreStep1ScreenState();
}

class _PlaceExploreStep1ScreenState extends State<PlaceExploreStep1Screen> {
  NaverMapController? _mapController;

  Future<void> _initMarkers(NaverMapController controller) async {
    for (int i = 0; i < widget.places.length; i++) {
      if (!mounted) return;
      final place = widget.places[i];
      final icon = await NOverlayImage.fromWidget(
        widget: PlacePin(number: i + 1),
        size: const Size(36, 36),
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

  void _showPlaceSheet(Place place) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => PlaceBottomSheet(place: place),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TripStepScaffold(
      onNext: widget.onNext,
      onPrev: widget.onPrev,
      children: [
        TripStepHeader(
          step: 1,
          title: '어디로 떠나볼까요?',
          subtitle: '원하는 장소 최소 3곳을 선택해주세요.',
        ),
        const SizedBox(height: 24),
        _buildMapArea(),
      ],
    );
  }

  Widget _buildMapArea() {
    return Container(
      width: double.infinity,
      height: 520,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.neutralScale[600]!.withAlpha(0x18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          NaverMap(
            options: const NaverMapViewOptions(
              initialCameraPosition: _kInitialCamera,
              scrollGesturesEnable: true,
              zoomGesturesEnable: true,
              rotationGesturesEnable: false,
              mapType: NMapType.basic,
            ),
            onMapReady: (controller) {
              _mapController = controller;
              _initMarkers(controller);
            },
          ),
          Positioned(
            right: 14,
            top: 0,
            bottom: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildGlassButton(
                    Icons.add,
                    () => _mapController?.updateCamera(NCameraUpdate.zoomIn()),
                  ),
                  const SizedBox(height: 8),
                  _buildGlassButton(
                    Icons.remove,
                    () => _mapController?.updateCamera(NCameraUpdate.zoomOut()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton(IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryScale[600]!.withAlpha(0x1A),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: 22, color: AppColors.primaryScale[500]),
          ),
        ),
      ),
    );
  }
}

