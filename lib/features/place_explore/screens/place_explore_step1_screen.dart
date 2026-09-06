import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/next_button.dart';
import '../../../common/widgets/prev_button.dart';
import '../../../core/maps/map_pointer.dart';
import '../../../core/maps/map_adapter.dart';
import '../../../core/maps/map_bootstrap.dart';
import '../models/place.dart';
import '../providers/place_explore_provider.dart';
import '../widgets/place_pin.dart';
import '../widgets/place_bottom_sheet.dart';
import '../widgets/glass_icon_button.dart';
import '../../trip/widgets/trip_step_header.dart';

const _kInitialCamera = MapCameraPosition(
  target: MapCoordinate(37.5666, 126.9784),
  zoom: 12.0,
);

/// 안내 글이 덮는 위쪽 높이. 단계 표시·제목·설명과 위아래 여백을 더한 값이다.
const _headerInset = 190.0;

/// 버튼이 덮는 아래쪽 높이. 다음·이전 버튼과 그 사이 여백을 더한 값이다.
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
  AppMapController? _mapController;
  bool _markersInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PlaceExploreProvider>().loadPlaces();
    });
  }

  // 한 번에 한 벌만 그린다. 지도를 다시 만들면 앞서 그리던 것이 아직 돌고 있을
  // 수 있는데, 마커 아이콘은 위젯을 그림 파일로 구워 만들고 그 굽는 자리가 앱
  // 전체에 하나뿐이라 겹쳐 돌면 서로의 파일을 지운다. 그 그림을 지도에 얹으려다
  // iOS 에서 앱이 죽는다.
  int _renderPass = 0;
  Future<void>? _renderInFlight;

  Future<void> _tryInitMarkers() async {
    final provider = context.read<PlaceExploreProvider>();
    if (_mapController == null || provider.places.isEmpty || _markersInitialized) return;
    _markersInitialized = true;
    final controller = _mapController!;
    final places = provider.places;

    // 번호를 먼저 올린다. 앞서 돌던 그리기가 이 값을 보고 다음 대기 지점에서
    // 스스로 물러난다.
    final pass = ++_renderPass;
    final previous = _renderInFlight;
    final done = Completer<void>();
    _renderInFlight = done.future;
    try {
      if (previous != null) await previous;
      if (!mounted || pass != _renderPass || _mapController != controller) return;
      await _initMarkers(controller, places, pass);
      if (!mounted || pass != _renderPass || _mapController != controller) return;
      await _fitCamera(controller, places);
    } finally {
      done.complete();
      if (identical(_renderInFlight, done.future)) _renderInFlight = null;
    }
  }

  /// 장소가 모두 들어오도록 지도를 옮긴다.
  ///
  /// 처음 보는 좌표는 고정값이라 다른 지역 일정이면 마커가 화면 밖에 남는다.
  Future<void> _fitCamera(
      AppMapController controller, List<Place> places) async {
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

    // 한 곳뿐이거나 같은 자리에 겹쳐 있으면 범위의 넓이가 0이 된다. 그때는
    // 범위 대신 가운데를 잡아 고정 배율로 옮긴다.
    const minSpan = 1e-6;
    if (maxLat - minLat < minSpan && maxLng - minLng < minSpan) {
      await controller.updateCamera(
        MapCameraUpdate.scrollAndZoomTo(
          target: MapCoordinate(minLat, minLng),
          zoom: 14,
        ),
      );
      return;
    }

    await controller.updateCamera(
      MapCameraUpdate.fitBounds(
        MapCoordinateBounds(
          southWest: MapCoordinate(minLat, minLng),
          northEast: MapCoordinate(maxLat, maxLng),
        ),
        padding: _mapInset(),
      ),
    );
  }

  /// 지도에서 가려지는 가장자리.
  ///
  /// 위아래 끝은 안내 글과 버튼이 덮고 있어, 그만큼 비워 두지 않으면 가장
  /// 바깥쪽 장소가 그 뒤로 들어간다. 창이 짧을 때 여백이 화면을 다 먹지
  /// 않도록 높이의 일부까지만 준다.
  EdgeInsets _mapInset() {
    final media = MediaQuery.of(context);
    final limit = media.size.height * 0.25;
    final top = math.min(media.padding.top + _headerInset, limit);
    final bottom = math.min(media.padding.bottom + _buttonsInset, limit);
    return EdgeInsets.fromLTRB(60, top, 60, bottom);
  }

  Future<void> _initMarkers(
      AppMapController controller, List<Place> places, int pass) async {
    // 지도가 바뀌었는지도 함께 본다. 번호만으로는 같은 순번에서 지도가 갈린
    // 경우를 못 가른다.
    bool stale() =>
        !mounted || pass != _renderPass || _mapController != controller;

    for (int i = 0; i < places.length; i++) {
      if (!mounted || stale()) return;
      final place = places[i];
      final icon = await MapOverlayImage.fromWidget(
        widget: PlacePin(number: i + 1),
        size: const Size(32, 40),
        context: context,
      );
      if (stale()) return;
      final marker = MapMarker(
        id: place.id,
        position: MapCoordinate(place.latitude, place.longitude),
        icon: icon,
      );
      marker.setOnTapListener((_) {
        if (mounted) _showPlaceSheet(place);
      });
      await controller.addOverlay(marker);
      if (stale()) return;
    }
  }

  Future<void> _showPlaceSheet(Place place) async {
    final provider = context.read<PlaceExploreProvider>();
    final detail = await provider.loadDetail(place.id);
    if (detail == null || !mounted) return;
    // 시트가 떠 있는 동안은 지도를 잠근다. 웹에서는 지도가 화면에 직접
    // 얹혀 있어, 잠그지 않으면 시트를 밀어도 지도만 움직인다.
    setMapPointerEnabled(false);
    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        useSafeArea: true,
        builder: (_) => PlaceBottomSheet(
          detail: detail,
          isAdded: provider.selectedIds.contains(place.id),
          onToggle: () => provider.togglePlace(place.id),
          latitude: place.latitude,
          longitude: place.longitude,
        ),
      );
    } finally {
      setMapPointerEnabled(true);
    }
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
          child: ValueListenableBuilder<int>(
            valueListenable: mapGeneration,
            builder: (context, generation, _) => AppMap(
              key: ValueKey('explore-map-$generation'),
              options: const AppMapOptions(
                initialCameraPosition: _kInitialCamera,
                scrollGesturesEnable: true,
                zoomGesturesEnable: true,
                rotationGesturesEnable: false,
                mapType: AppMapType.basic,
                contentPadding: EdgeInsets.only(bottom: 160),
              ),
              onMapReady: (controller) {
                // 새로 만든 지도에는 마커가 없다. 그렸다는 표시를 지워 다시
                // 그리게 한다.
                if (!identical(_mapController, controller)) {
                  _markersInitialized = false;
                }
                _mapController = controller;
                _tryInitMarkers();
              },
            ),
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
                      _mapController?.updateCamera(MapCameraUpdate.zoomIn()),
                ),
                const SizedBox(height: 8),
                GlassIconButton(
                  icon: Icons.remove,
                  onPressed: () =>
                      _mapController?.updateCamera(MapCameraUpdate.zoomOut()),
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

  /// 고를 장소가 없을 때의 안내.
  ///
  /// 탐색은 방금 만든 일정의 장소를 다시 고르는 자리라, 일정 없이 들어오면
  /// 지도에 아무것도 찍히지 않는다. 빈 지도만 보이면 고장으로 읽히므로
  /// 무엇이 없는지 알려 준다.
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
