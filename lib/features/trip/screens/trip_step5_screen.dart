import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/theme/app_icons.dart';
import '../widgets/trip_step_header.dart';
import '../widgets/trip_step_scaffold.dart';

class TripStep5Screen extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final String selectedProvince;
  final String selectedCity;
  final void Function(String province, String city) onLocationChanged;

  const TripStep5Screen({
    super.key,
    required this.onNext,
    required this.onPrev,
    required this.selectedProvince,
    required this.selectedCity,
    required this.onLocationChanged,
  });

  @override
  State<TripStep5Screen> createState() => _TripStep5ScreenState();
}

class _TripStep5ScreenState extends State<TripStep5Screen> {
  NaverMapController? _mapController;
  Map<String, dynamic>? _sidoGeo;
  Map<String, dynamic>? _sggGeo;

  static const _kOverlayProvince = 'overlay_province';
  static const _kOverlayCity = 'overlay_city';
  static const _kOverlayColor = Color(0x1A7C3AED);
  static const _kOverlayOutline = Color(0xFF7C3AED);

  static const _kPlaceholder = '선택';

  static const _kKoreaOverview = NCameraPosition(
    target: NLatLng(36.0, 128.5),
    zoom: 6.0,
  );

  static const List<String> _provinces = [
    '서울특별시', '부산광역시', '대구광역시', '인천광역시', '광주광역시',
    '대전광역시', '울산광역시', '세종특별자치시', '경기도', '강원도',
    '충청북도', '충청남도', '전라북도', '전라남도', '경상북도',
    '경상남도', '제주특별자치도',
  ];

  static const Map<String, List<String>> _cities = {
    '강원도': ['춘천시', '원주시', '강릉시', '동해시', '태백시', '속초시', '삼척시', '홍천군', '횡성군', '영월군', '평창군', '정선군', '철원군', '화천군', '양구군', '인제군', '고성군', '양양군'],
    '서울특별시': ['종로구', '중구', '용산구', '성동구', '광진구', '동대문구', '중랑구', '성북구', '강북구', '도봉구', '노원구', '은평구', '서대문구', '마포구', '양천구', '강서구', '구로구', '금천구', '영등포구', '동작구', '관악구', '서초구', '강남구', '송파구', '강동구'],
    '경기도': ['수원시', '성남시', '고양시', '용인시', '부천시', '안산시', '안양시', '남양주시', '화성시', '평택시', '의정부시', '시흥시', '파주시', '광명시', '김포시', '군포시', '광주시', '이천시', '양주시', '오산시'],
  };

  Future<void> _loadGeoJson() async {
    final sidoStr = await rootBundle.loadString('assets/geo/TL_SCCO_CTPRVN.json');
    final sggStr = await rootBundle.loadString('assets/geo/TL_SCCO_SIG.json');
    _sidoGeo = json.decode(sidoStr) as Map<String, dynamic>;
    _sggGeo = json.decode(sggStr) as Map<String, dynamic>;
  }

  List<NLatLng> _coordsToLatLng(List<dynamic> ring) =>
      ring.map((p) => NLatLng(p[1] as double, p[0] as double)).toList();

  /// 시도 이름 → CTPRVN_CD (e.g. '서울특별시' → '11')
  String? _getProvinceCode(String provinceName) {
    for (final feature in (_sidoGeo!['features'] as List<dynamic>)) {
      final props = feature['properties'] as Map<String, dynamic>;
      if (props['CTP_KOR_NM'] == provinceName) {
        return props['CTPRVN_CD'] as String?;
      }
    }
    return null;
  }

  List<NPolygonOverlay> _buildOverlays(
    String idPrefix,
    List<dynamic> features,
    String nameKey,
    String matchName, {
    String? provinceCode,
  }) {
    final overlays = <NPolygonOverlay>[];
    int idx = 0;
    for (final feature in features) {
      final props = feature['properties'] as Map<String, dynamic>;
      if (props[nameKey] != matchName) continue;
      if (provinceCode != null) {
        final sigCd = props['SIG_CD'] as String? ?? '';
        if (!sigCd.startsWith(provinceCode)) continue;
      }
      final geom = feature['geometry'] as Map<String, dynamic>;
      final type = geom['type'] as String;
      final coords = geom['coordinates'] as List<dynamic>;
      if (type == 'Polygon') {
        overlays.add(_makeOverlay('${idPrefix}_$idx', coords));
        idx++;
      } else if (type == 'MultiPolygon') {
        for (final poly in coords) {
          overlays.add(_makeOverlay('${idPrefix}_$idx', poly as List<dynamic>));
          idx++;
        }
      }
    }
    return overlays;
  }

  NPolygonOverlay _makeOverlay(String id, List<dynamic> rings) {
    final outer = _coordsToLatLng(rings[0] as List<dynamic>);
    final holes = rings.length > 1
        ? rings.sublist(1).map((r) => _coordsToLatLng(r as List<dynamic>)).toList()
        : <List<NLatLng>>[];
    return NPolygonOverlay(
      id: id,
      coords: outer,
      holes: holes,
      color: _kOverlayColor,
      outlineColor: _kOverlayOutline,
      outlineWidth: 2,
    );
  }

  /// 매칭된 feature들의 좌표 전체를 아우르는 NLatLngBounds 계산
  NLatLngBounds? _computeBounds(
    List<dynamic> features,
    String nameKey,
    String matchName, {
    String? provinceCode,
  }) {
    double? minLat, maxLat, minLng, maxLng;

    void processRing(List<dynamic> ring) {
      for (final p in ring) {
        final lng = (p[0] as num).toDouble();
        final lat = (p[1] as num).toDouble();
        minLat = minLat == null || lat < minLat! ? lat : minLat;
        maxLat = maxLat == null || lat > maxLat! ? lat : maxLat;
        minLng = minLng == null || lng < minLng! ? lng : minLng;
        maxLng = maxLng == null || lng > maxLng! ? lng : maxLng;
      }
    }

    for (final feature in features) {
      final props = feature['properties'] as Map<String, dynamic>;
      if (props[nameKey] != matchName) continue;
      if (provinceCode != null) {
        final sigCd = props['SIG_CD'] as String? ?? '';
        if (!sigCd.startsWith(provinceCode)) continue;
      }
      final geom = feature['geometry'] as Map<String, dynamic>;
      final type = geom['type'] as String;
      final coords = geom['coordinates'] as List<dynamic>;
      if (type == 'Polygon') {
        processRing(coords[0] as List<dynamic>);
      } else if (type == 'MultiPolygon') {
        for (final poly in coords) {
          processRing((poly as List<dynamic>)[0] as List<dynamic>);
        }
      }
    }

    if (minLat == null) return null;
    return NLatLngBounds(
      southWest: NLatLng(minLat!, minLng!),
      northEast: NLatLng(maxLat!, maxLng!),
    );
  }

  void _fitBounds(NLatLngBounds bounds) {
    _mapController?.updateCamera(
      NCameraUpdate.fitBounds(bounds, padding: const EdgeInsets.all(48))
        ..setAnimation(
          animation: NCameraAnimation.easing,
          duration: const Duration(milliseconds: 600),
        ),
    );
  }

  Future<void> _updateOverlays() async {
    final controller = _mapController;
    if (controller == null) return;

    if (_sidoGeo == null || _sggGeo == null) await _loadGeoJson();

    await controller.clearOverlays(type: NOverlayType.polygonOverlay);

    final province = widget.selectedProvince;
    final city = widget.selectedCity;

    if (province == _kPlaceholder) {
      // 한국 전체 뷰로 복귀
      controller.updateCamera(
        NCameraUpdate.fromCameraPosition(_kKoreaOverview)
          ..setAnimation(
            animation: NCameraAnimation.easing,
            duration: const Duration(milliseconds: 600),
          ),
      );
      return;
    }

    if (city == _kPlaceholder) {
      // 시/도 오버레이 + 해당 시도 전체가 보이도록 fitBounds
      final sidoFeatures = _sidoGeo!['features'] as List<dynamic>;
      final overlays = _buildOverlays(_kOverlayProvince, sidoFeatures, 'CTP_KOR_NM', province);
      await controller.addOverlayAll(overlays.toSet());
      final bounds = _computeBounds(sidoFeatures, 'CTP_KOR_NM', province);
      if (bounds != null) _fitBounds(bounds);
    } else {
      // 시/군/구 오버레이 + 해당 구 전체가 보이도록 fitBounds
      // provinceCode로 동명 시군구(중구 등) 중복 방지
      final provinceCode = _getProvinceCode(province);
      final sggFeatures = _sggGeo!['features'] as List<dynamic>;
      final overlays = _buildOverlays(
        _kOverlayCity, sggFeatures, 'SIG_KOR_NM', city,
        provinceCode: provinceCode,
      );
      await controller.addOverlayAll(overlays.toSet());
      final bounds = _computeBounds(
        sggFeatures, 'SIG_KOR_NM', city,
        provinceCode: provinceCode,
      );
      if (bounds != null) _fitBounds(bounds);
    }
  }

  @override
  void didUpdateWidget(TripStep5Screen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedProvince != widget.selectedProvince ||
        oldWidget.selectedCity != widget.selectedCity) {
      _updateOverlays();
    }
  }

  List<String> _availableCities(String province) {
    if (province == _kPlaceholder) return [_kPlaceholder];
    final list = _cities[province] ?? ['해당 시/군/구 없음'];
    return [_kPlaceholder, ...list];
  }

  bool get _canProceed =>
      widget.selectedProvince != _kPlaceholder && widget.selectedCity != _kPlaceholder;

  @override
  Widget build(BuildContext context) {
    final cities = _availableCities(widget.selectedProvince);
    final effectiveCity = cities.contains(widget.selectedCity) ? widget.selectedCity : _kPlaceholder;

    return TripStepScaffold(
      onNext: _canProceed ? widget.onNext : null,
      onPrev: widget.onPrev,
      children: [
        TripStepHeader(
          step: 5,
          title: '어디로 떠나볼까요?',
          subtitle: '당신의 여정이 시작될 출발지를 선택해주세요.',
          isNextEnabled: _canProceed,
        ),
        const SizedBox(height: 28),
        // ── 지역 드롭다운 ──
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildDropdown(
                label: '시/도',
                value: widget.selectedProvince,
                items: [_kPlaceholder, ..._provinces],
                onChanged: (v) {
                  if (v == null) return;
                  widget.onLocationChanged(v, _kPlaceholder);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdown(
                label: '시/군/구',
                value: effectiveCity,
                items: cities,
                onChanged: (v) {
                  if (v != null) widget.onLocationChanged(widget.selectedProvince, v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildMapArea(),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final isPlaceholder = value == _kPlaceholder;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.neutralScale[400],
          ),
        ),
        const SizedBox(height: 8),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: AppIcon(SvgIcons.chevronDownGray, size: 10,
                  color: AppColors.neutralScale[400]),
              // '선택' 상태일 때 힌트처럼 회색으로 표시
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isPlaceholder
                    ? AppColors.neutralScale[300]
                    : AppColors.neutralScale[600],
              ),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(14),
              items: items.map((item) => DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: item == _kPlaceholder
                        ? AppColors.neutralScale[300]
                        : AppColors.neutralScale[600],
                      ),
                ),
              )).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapArea() {
    return Container(
      width: double.infinity,
      height: 320,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
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
              initialCameraPosition: _kKoreaOverview,
              scrollGesturesEnable: true,
              zoomGesturesEnable: true,
              rotationGesturesEnable: false,
              mapType: NMapType.basic,
            ),
            onMapReady: (controller) {
              _mapController = controller;
              _updateOverlays();
            },
          ),
          // ── 글라스 +/- 버튼 ──
          Positioned(
            right: 14,
            top: 0,
            bottom: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildGlassButton(Icons.add, () {
                    _mapController?.updateCamera(NCameraUpdate.zoomIn());
                  }),
                  const SizedBox(height: 8),
                  _buildGlassButton(Icons.remove, () {
                    _mapController?.updateCamera(NCameraUpdate.zoomOut());
                  }),
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
