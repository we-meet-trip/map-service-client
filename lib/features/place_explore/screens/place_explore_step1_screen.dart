import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/next_button.dart';
import '../../../common/widgets/prev_button.dart';
import '../../../core/naver_map/naver_map_adapter.dart';
import '../models/place.dart';
import '../data/place_detail_mock.dart';
import '../widgets/place_pin.dart';
import '../widgets/place_bottom_sheet.dart';
import '../widgets/glass_icon_button.dart';
import '../../trip/widgets/trip_step_header.dart';

const _kMinSelection = 3;

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
  final Set<String> _selectedIds = {};

  bool get _canProceed => _selectedIds.length >= _kMinSelection;

  String? get _nextInfo {
    final need = _kMinSelection - _selectedIds.length;
    if (need <= 0) return null;
    return '장소 $need개 더 선택하면 다음으로';
  }

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

  void _togglePlace(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _showPlaceSheet(Place place) {
    final detail = mockPlaceDetails[place.id];
    if (detail == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => PlaceBottomSheet(
        detail: detail,
        isAdded: _selectedIds.contains(place.id),
        onToggle: () => _togglePlace(place.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Stack(
      children: [
        // ── 지도: 전체 배경 ────────────────────────────────────────
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
              _initMarkers(controller);
            },
          ),
        ),

        // ── 헤더: 상단 그라데이션 오버레이 위 텍스트 ─────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildHeader(topPad),
        ),

        // ── 줌 버튼 ───────────────────────────────────────────────
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
                  onPressed: () => _mapController?.updateCamera(NCameraUpdate.zoomIn()),
                ),
                const SizedBox(height: 8),
                GlassIconButton(
                  icon: Icons.remove,
                  onPressed: () => _mapController?.updateCamera(NCameraUpdate.zoomOut()),
                ),
              ],
            ),
          ),
        ),

        // ── 선택 배지 ─────────────────────────────────────────────
        if (_selectedIds.isNotEmpty)
          Positioned(
            left: 14,
            top: topPad + 160,
            child: _buildSelectionBadge(),
          ),

        // ── 버튼: 하단 메뉴바 바로 위 고정 ───────────────────────────
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildButtons(bottomPad),
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
            Colors.white,
            Colors.white,
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.72, 1.0],
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, topPad + 20, 24, 40),
      child: TripStepHeader(
        step: 1,
        totalSteps: 2,
        title: '어디로 떠나볼까요?',
        subtitle: '원하는 장소 최소 3곳을 선택해주세요.',
      ),
    );
  }

  Widget _buildButtons(double bottomPad) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.white,
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.10, 1.0],
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, 40, 24, bottomPad + 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NextButton(
            onPressed: _canProceed ? widget.onNext : null,
            info: _nextInfo,
          ),
          const SizedBox(height: 10),
          PrevButton(onPressed: widget.onPrev),
        ],
      ),
    );
  }

  Widget _buildSelectionBadge() {
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
            '${_selectedIds.length}곳 선택됨',
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
