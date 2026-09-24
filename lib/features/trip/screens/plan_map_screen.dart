import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../common/constants/korea_regions.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/next_button.dart';
import '../../../common/widgets/prev_button.dart';
import '../../../core/api/places_api_service.dart';
import '../../../core/maps/map_adapter.dart';
import '../../../core/maps/map_bootstrap.dart';
import '../../../core/maps/map_pointer.dart';
import '../../place_explore/models/place_detail.dart';
import '../../place_explore/widgets/glass_icon_button.dart';
import '../../place_explore/widgets/place_bottom_sheet.dart';
import '../../place_explore/widgets/place_pin.dart';
import '../widgets/trip_card.dart';
import '../widgets/trip_step_header.dart';

/// 검색 결과가 그 지역 안의 장소인지.
///
/// 서버는 지역 이름을 좌표로 바꾼 뒤 그 둘레를 찾는데, 바꾸지 못하면 지역
/// 제한 없이 찾는다. 행정구역 이름이 바뀐 곳에서 그런 일이 생겨 다른 도시의
/// 같은 이름 장소가 섞일 수 있어, 주소에 시도와 시군구가 모두 들어 있는
/// 것만 남긴다. 주소가 없는 결과(코스 등)는 판단할 수 없어 그대로 둔다.
bool placeInRegion(PlaceSearchItem item, String province, String? city) {
  final addresses = [item.roadAddress, item.address].where((a) => a.isNotEmpty);
  if (addresses.isEmpty) return true;
  final shortProvince = kProvinceShortNames[province] ?? province;
  return addresses.any(
    (a) => a.contains(shortProvince) && (city == null || a.contains(city)),
  );
}

/// 지역 안 장소 검색. 시험에서 서버 대신 넣는다.
typedef PlaceSearch =
    Future<List<PlaceSearchItem>> Function({
      required String province,
      String? city,
      String? query,
    });

/// 지도에서 장소를 찾아 담는 화면. AI 를 거치지 않는다.
///
/// 장소를 누르면 블로그 후기를 담은 상세 시트가 열리고, 거기서 경로에 담는다.
/// 담은 장소는 [onNext] 로 넘겨 동선을 짜는 화면으로 간다. [onNext] 가 없으면
/// 담지 않고 둘러보기만 한다(랜덤 미션처럼 일정을 만들지 않는 자리).
class PlanMapScreen extends StatefulWidget {
  const PlanMapScreen({
    super.key,
    required this.province,
    required this.city,
    this.onNext,
    required this.onPrev,
    this.initialQuery,
    this.initialSelection = const [],
    this.headline = '가고 싶은 곳을 담아요',
    this.step = 3,
    this.totalSteps = 3,
    this.api,
  });

  final String province;

  /// 시군구. 시도 전체를 고른 경우 없다.
  final String? city;
  final void Function(List<PlaceSearchItem> selected)? onNext;

  bool get browseOnly => onNext == null;
  final VoidCallback onPrev;

  /// 처음 검색할 낱말. 없으면 지역의 대표 장소를 보여 준다.
  final String? initialQuery;
  final List<PlaceSearchItem> initialSelection;
  final String headline;

  /// 앞 단계(날짜·지역)와 이어지는 진행 표시.
  final int step;
  final int totalSteps;
  final PlaceSearch? api;

  @override
  State<PlanMapScreen> createState() => _PlanMapScreenState();
}

String _keyOf(PlaceSearchItem item) => item.contentId.isNotEmpty
    ? item.contentId
    : '${item.name}@${item.latitude},${item.longitude}';

class _PlanMapScreenState extends State<PlanMapScreen> {
  late final TextEditingController _query = TextEditingController(
    text: widget.initialQuery ?? '',
  );

  /// 담은 순서를 그대로 지킨다. 동선 화면에 이 순서로 넘어간다.
  late final Map<String, PlaceSearchItem> _selected = {
    for (final item in widget.initialSelection) _keyOf(item): item,
  };

  /// 검색을 마치면 포커스가 풀려 가려 둔 안내·단추가 돌아온다.
  late final FocusNode _searchFocus = FocusNode()
    ..addListener(() {
      if (mounted) setState(() {});
    });

  List<PlaceSearchItem> _results = const [];
  bool _loading = false;
  String? _message;
  AppMapController? _mapController;

  // 마커 아이콘은 위젯을 그림으로 구워 만드는데 그 자리가 앱 전체에 하나라,
  // 두 벌이 겹쳐 돌면 서로의 그림을 지운다. 한 번에 한 벌만 그린다.
  int _renderPass = 0;
  Future<void>? _renderInFlight;

  String get _regionLabel => regionLabel(widget.province, widget.city);

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _query.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final api = widget.api ?? PlacesApiService.instance.search;
      final found = await api(
        province: widget.province,
        city: widget.city,
        query: query.isEmpty ? null : query,
      );
      if (!mounted) return;
      final inRegion = found
          .where((item) => placeInRegion(item, widget.province, widget.city))
          .toList();
      setState(() {
        _results = inRegion;
        _loading = false;
        _message = inRegion.isEmpty
            ? '$_regionLabel 중심 근처에서 찾은 장소가 없어요.\n'
                  '${widget.browseOnly ? '다른 낱말로 찾거나 미션을 다시 뽑아 보세요.' : '다른 낱말(예: 카페, 공원)로 찾아보세요.'}'
            : null;
      });
      _renderMarkers();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = '장소를 찾지 못했어요. 잠시 후 다시 시도해주세요.';
      });
    }
  }

  Future<void> _renderMarkers() async {
    final controller = _mapController;
    if (controller == null) return;
    final pass = ++_renderPass;
    final previous = _renderInFlight;
    final done = Completer<void>();
    _renderInFlight = done.future;
    bool stale() =>
        !mounted || pass != _renderPass || _mapController != controller;
    try {
      if (previous != null) await previous;
      if (stale()) return;
      await controller.clearOverlays(type: MapOverlayType.marker);
      final places = _results;
      for (var i = 0; i < places.length; i++) {
        if (!mounted || stale()) return;
        final place = places[i];
        final icon = await MapOverlayImage.fromWidget(
          widget: PlacePin(number: i + 1),
          size: const Size(32, 40),
          context: context,
        );
        if (stale()) return;
        final marker = MapMarker(
          id: 'plan-${_keyOf(place)}',
          position: MapCoordinate(place.latitude, place.longitude),
          icon: icon,
        );
        marker.setOnTapListener((_) {
          if (mounted) _openPlace(place);
        });
        await controller.addOverlay(marker);
      }
      if (!stale()) await _fitCamera(controller, places);
    } finally {
      done.complete();
      if (identical(_renderInFlight, done.future)) _renderInFlight = null;
    }
  }

  Future<void> _fitCamera(
    AppMapController controller,
    List<PlaceSearchItem> places,
  ) async {
    if (places.isEmpty) return;
    var minLat = places.first.latitude, maxLat = minLat;
    var minLng = places.first.longitude, maxLng = minLng;
    for (final p in places) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    // 한 곳뿐이면 범위의 넓이가 0이라 가운데를 잡아 고정 배율로 옮긴다.
    if (maxLat - minLat < 1e-6 && maxLng - minLng < 1e-6) {
      await controller.updateCamera(
        MapCameraUpdate.scrollAndZoomTo(
          target: MapCoordinate(minLat, minLng),
          zoom: 14,
        ),
      );
      return;
    }
    final media = MediaQuery.of(context);
    final limit = media.size.height * 0.25;
    await controller.updateCamera(
      MapCameraUpdate.fitBounds(
        MapCoordinateBounds(
          southWest: MapCoordinate(minLat, minLng),
          northEast: MapCoordinate(maxLat, maxLng),
        ),
        padding: EdgeInsets.fromLTRB(
          60,
          math.min(media.padding.top + 230, limit),
          60,
          math.min(media.padding.bottom + 170, limit),
        ),
      ),
    );
  }

  void _toggle(PlaceSearchItem item) {
    final key = _keyOf(item);
    setState(() {
      if (_selected.remove(key) == null) _selected[key] = item;
    });
  }

  Future<void> _openPlace(PlaceSearchItem item) async {
    // 시트가 떠 있는 동안은 지도를 잠근다. 웹에서는 지도가 화면에 직접 얹혀
    // 있어, 잠그지 않으면 시트를 밀어도 지도만 움직인다.
    setMapPointerEnabled(false);
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        useSafeArea: true,
        builder: (_) => PlaceBottomSheet(
          detail: PlaceDetail(
            id: _keyOf(item),
            name: item.name,
            address: item.displayAddress,
            category: item.category,
          ),
          isAdded: _selected.containsKey(_keyOf(item)),
          onToggle: widget.browseOnly ? null : () => _toggle(item),
          latitude: item.latitude,
          longitude: item.longitude,
          showAiSummary: false,
        ),
      );
    } finally {
      setMapPointerEnabled(true);
    }
  }

  /// 지도 마커를 누르기 어려운 사람(화면 읽기 등)도 같은 결과를 고를 수 있게
  /// 목록으로도 보여 준다.
  Future<void> _openList() async {
    final picked = await showModalBottomSheet<PlaceSearchItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        height: MediaQuery.of(sheetContext).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.neutralScale[200],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '찾은 장소 ${_results.length}곳',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutralScale[600],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  8,
                  0,
                  8,
                  12 + MediaQuery.paddingOf(sheetContext).bottom,
                ),
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final item = _results[index];
                  final added = _selected.containsKey(_keyOf(item));
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.secondaryScale[100],
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondaryScale[900],
                        ),
                      ),
                    ),
                    title: Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.neutralScale[600],
                      ),
                    ),
                    subtitle: Text(
                      item.displayAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.neutralScale[400],
                      ),
                    ),
                    trailing: added
                        ? Icon(
                            Icons.check_circle,
                            color: AppColors.secondaryScale[500],
                          )
                        : null,
                    onTap: () => Navigator.of(sheetContext).pop(item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) await _openPlace(picked);
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    // 키보드가 올라오면 바깥 탭 화면이 이 화면을 줄여, 가운데 안내·확대 단추가
    // 위로 밀려 검색창을 덮는다. 검색어를 치는 동안에는 검색창만 남긴다. 키보드
    // 높이는 바깥 화면이 가져가 여기서 보이지 않으므로 검색창 포커스로 판단한다.
    final typing = _searchFocus.hasFocus;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: ValueListenableBuilder<int>(
              valueListenable: mapGeneration,
              builder: (context, generation, _) => AppMap(
                key: ValueKey('plan-map-$generation'),
                options: AppMapOptions(
                  initialCameraPosition: const MapCameraPosition(
                    target: MapCoordinate(36.0, 128.5),
                    zoom: 7.0,
                  ),
                  scrollGesturesEnable: true,
                  zoomGesturesEnable: true,
                  rotationGesturesEnable: false,
                  mapType: AppMapType.basic,
                  contentPadding: EdgeInsets.only(bottom: 166 + bottomPad),
                ),
                onMapReady: (controller) {
                  _mapController = controller;
                  _renderMarkers();
                },
              ),
            ),
          ),
          Positioned(top: 0, left: 0, right: 0, child: _buildHeader(topPad)),
          // 안내 문구가 떠 있을 때는 볼 장소가 없어 확대 단추를 숨긴다. 둘 다
          // 화면 가운데에 놓여 겹치기 때문이다.
          if (_message == null && !typing)
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
                      onPressed: () => _mapController?.updateCamera(
                        MapCameraUpdate.zoomIn(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GlassIconButton(
                      icon: Icons.remove,
                      onPressed: () => _mapController?.updateCamera(
                        MapCameraUpdate.zoomOut(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_message != null && !typing)
            Positioned(
              left: 24,
              right: 24,
              top: 0,
              bottom: 0,
              child: Center(child: _buildNotice(_message!)),
            ),
          if (!typing)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildButtons(bottomPad),
            ),
        ],
      ),
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
      padding: EdgeInsets.fromLTRB(24, topPad + 24, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TripStepHeader(
            step: widget.step,
            totalSteps: widget.totalSteps,
            isNextEnabled: widget.browseOnly || _selected.isNotEmpty,
            title: widget.headline,
            subtitle: widget.browseOnly
                ? '$_regionLabel · 장소를 눌러 후기를 봐요'
                : '$_regionLabel · 장소를 눌러 후기를 보고 담아요',
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neutralScale[600]!.withAlpha(0x12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _query,
              focusNode: _searchFocus,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.neutralScale[600],
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                hintText: '장소 이름이나 종류로 찾기 (예: 카페)',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: AppColors.neutralScale[400],
                ),
                // 기본 48px 자리는 알약 모양에서 아이콘과 글자 사이를 너무 띄운다.
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 18, right: 8),
                  child: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: AppColors.neutralScale[400],
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(),
                suffixIcon: IconButton(
                  tooltip: '검색',
                  icon: Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.secondaryScale[500],
                  ),
                  onPressed: _loading ? null : _search,
                ),
              ),
            ),
          ),
          if (_loading) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 3,
                color: AppColors.secondaryScale[500],
                backgroundColor: AppColors.secondaryScale[100],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotice(String text) {
    return TripCard(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.neutralScale[600],
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildButtons(double bottomPad) {
    final count = _selected.length;
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
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_results.isNotEmpty) _buildListChip(),
          if (widget.onNext case final onNext?)
            Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 10 + bottomPad),
              child: NextButton(
                onPressed: count > 0
                    ? () => onNext(_selected.values.toList())
                    : null,
                info: count > 0 ? '$count곳 담음' : '장소를 눌러 담아 주세요',
              ),
            )
          else
            SizedBox(height: 16 + bottomPad),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: PrevButton(onPressed: widget.onPrev),
          ),
        ],
      ),
    );
  }

  Widget _buildListChip() {
    // 검색창과 같은 흰 알약 모양으로 지도 위에 띄운다.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: AppColors.neutralScale[600]!.withAlpha(0x12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Semantics(
        button: true,
        child: Material(
          color: Colors.white,
          shape: const StadiumBorder(),
          child: InkWell(
            onTap: _openList,
            customBorder: const StadiumBorder(),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.list_rounded,
                    size: 18,
                    color: AppColors.secondaryScale[500],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '찾은 장소 목록 (${_results.length})',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutralScale[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
