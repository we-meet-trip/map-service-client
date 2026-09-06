import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/theme/app_icons.dart';
import '../widgets/trip_step_header.dart';
import '../widgets/trip_step_scaffold.dart';

class GoogleTripStep5Screen extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final String selectedProvince;
  final String selectedCity;
  final void Function(String province, String city) onLocationChanged;

  const GoogleTripStep5Screen({
    super.key,
    required this.onNext,
    required this.onPrev,
    required this.selectedProvince,
    required this.selectedCity,
    required this.onLocationChanged,
  });

  @override
  State<GoogleTripStep5Screen> createState() => _GoogleTripStep5ScreenState();
}

class _GoogleTripStep5ScreenState extends State<GoogleTripStep5Screen> {
  GoogleMapController? _mapController;
  Set<Polygon> _polygons = const {};
  Map<String, dynamic>? _sidoGeo;
  Map<String, dynamic>? _sggGeo;

  static const _kOverlayProvince = 'overlay_province';
  static const _kOverlayCity = 'overlay_city';
  static const _kOverlayColor = Color(0x1A7C3AED);
  static const _kOverlayOutline = Color(0xFF7C3AED);

  static const _kPlaceholder = '선택';
  static const _kAllCities = '전체';

  static const _kKoreaOverview = CameraPosition(
    target: LatLng(36.0, 128.5),
    zoom: 6.0,
  );

  static const List<String> _provinces = [
    '서울특별시', '부산광역시', '대구광역시', '인천광역시', '광주광역시',
    '대전광역시', '울산광역시', '세종특별자치시', '경기도', '강원도',
    '충청북도', '충청남도', '전라북도', '전라남도', '경상북도',
    '경상남도', '제주특별자치도',
  ];

  static const Map<String, List<String>> _cities = {
    '서울특별시': [
      '종로구', '중구', '용산구', '성동구', '광진구', '동대문구', '중랑구', '성북구',
      '강북구', '도봉구', '노원구', '은평구', '서대문구', '마포구', '양천구', '강서구',
      '구로구', '금천구', '영등포구', '동작구', '관악구', '서초구', '강남구', '송파구', '강동구',
    ],
    '부산광역시': [
      '중구', '서구', '동구', '영도구', '부산진구', '동래구', '남구', '북구',
      '해운대구', '사하구', '금정구', '강서구', '연제구', '수영구', '사상구', '기장군',
    ],
    '대구광역시': [
      '중구', '동구', '서구', '남구', '북구', '수성구', '달서구', '달성군', '군위군',
    ],
    '인천광역시': [
      '중구', '동구', '미추홀구', '연수구', '남동구', '부평구', '계양구', '서구',
      '강화군', '옹진군',
    ],
    '광주광역시': ['동구', '서구', '남구', '북구', '광산구'],
    '대전광역시': ['동구', '중구', '서구', '유성구', '대덕구'],
    '울산광역시': ['중구', '남구', '동구', '북구', '울주군'],
    '세종특별자치시': ['세종시'],
    '경기도': [
      '수원시', '성남시', '고양시', '용인시', '부천시', '안산시', '안양시', '남양주시',
      '화성시', '평택시', '의정부시', '시흥시', '파주시', '광명시', '김포시', '군포시',
      '광주시', '이천시', '양주시', '오산시', '구리시', '안성시', '포천시', '의왕시',
      '하남시', '여주시', '동두천시', '과천시', '가평군', '양평군', '연천군',
    ],
    '강원도': [
      '춘천시', '원주시', '강릉시', '동해시', '태백시', '속초시', '삼척시',
      '홍천군', '횡성군', '영월군', '평창군', '정선군', '철원군', '화천군',
      '양구군', '인제군', '고성군', '양양군',
    ],
    '충청북도': [
      '청주시', '충주시', '제천시', '보은군', '옥천군', '영동군', '증평군',
      '진천군', '괴산군', '음성군', '단양군',
    ],
    '충청남도': [
      '천안시', '공주시', '보령시', '아산시', '서산시', '논산시', '계룡시', '당진시',
      '금산군', '부여군', '서천군', '청양군', '홍성군', '예산군', '태안군',
    ],
    '전라북도': [
      '전주시', '군산시', '익산시', '정읍시', '남원시', '김제시',
      '완주군', '진안군', '무주군', '장수군', '임실군', '순창군', '고창군', '부안군',
    ],
    '전라남도': [
      '목포시', '여수시', '순천시', '나주시', '광양시',
      '담양군', '곡성군', '구례군', '고흥군', '보성군', '화순군', '장흥군', '강진군',
      '해남군', '영암군', '무안군', '함평군', '영광군', '장성군', '완도군', '진도군', '신안군',
    ],
    '경상북도': [
      '포항시', '경주시', '김천시', '안동시', '구미시', '영주시', '영천시',
      '상주시', '문경시', '경산시',
      '의성군', '청송군', '영양군', '영덕군', '청도군', '고령군', '성주군', '칠곡군',
      '예천군', '봉화군', '울진군', '울릉군',
    ],
    '경상남도': [
      '창원시', '진주시', '통영시', '사천시', '김해시', '밀양시', '거제시', '양산시',
      '의령군', '함안군', '창녕군', '고성군', '남해군', '하동군', '산청군', '함양군',
      '거창군', '합천군',
    ],
    '제주특별자치도': ['제주시', '서귀포시'],
  };

  Future<void> _loadGeoJson() async {
    final sidoStr = await rootBundle.loadString('assets/geo/TL_SCCO_CTPRVN.json');
    final sggStr = await rootBundle.loadString('assets/geo/TL_SCCO_SIG.json');
    _sidoGeo = json.decode(sidoStr) as Map<String, dynamic>;
    _sggGeo = json.decode(sggStr) as Map<String, dynamic>;
  }

  List<LatLng> _coordsToLatLng(List<dynamic> ring) =>
      ring.map((p) => LatLng(p[1] as double, p[0] as double)).toList();

  String? _getProvinceCode(String provinceName) {
    for (final feature in (_sidoGeo!['features'] as List<dynamic>)) {
      final props = feature['properties'] as Map<String, dynamic>;
      if (props['CTP_KOR_NM'] == provinceName) {
        return props['CTPRVN_CD'] as String?;
      }
    }
    return null;
  }

  Set<Polygon> _buildPolygons(
    String idPrefix,
    List<dynamic> features,
    String nameKey,
    String matchName, {
    String? provinceCode,
  }) {
    final polygons = <Polygon>{};
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
        polygons.add(_makePolygon('${idPrefix}_$idx', coords));
        idx++;
      } else if (type == 'MultiPolygon') {
        for (final poly in coords) {
          polygons.add(_makePolygon('${idPrefix}_$idx', poly as List<dynamic>));
          idx++;
        }
      }
    }
    return polygons;
  }

  Polygon _makePolygon(String id, List<dynamic> rings) {
    final outer = _coordsToLatLng(rings[0] as List<dynamic>);
    final holes = rings.length > 1
        ? rings.sublist(1).map((r) => _coordsToLatLng(r as List<dynamic>)).toList()
        : <List<LatLng>>[];
    return Polygon(
      polygonId: PolygonId(id),
      points: outer,
      holes: holes,
      fillColor: _kOverlayColor,
      strokeColor: _kOverlayOutline,
      strokeWidth: 2,
    );
  }

  LatLngBounds? _computeBounds(
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
    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  void _fitBounds(LatLngBounds bounds) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 48),
    );
  }

  Future<void> _updateOverlays() async {
    if (_sidoGeo == null || _sggGeo == null) await _loadGeoJson();
    if (!mounted) return;

    final province = widget.selectedProvince;
    final city = widget.selectedCity;

    if (province == _kPlaceholder) {
      setState(() => _polygons = const {});
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(_kKoreaOverview),
      );
      return;
    }

    if (city == _kPlaceholder || city == _kAllCities) {
      final sidoFeatures = _sidoGeo!['features'] as List<dynamic>;
      final polygons = _buildPolygons(_kOverlayProvince, sidoFeatures, 'CTP_KOR_NM', province);
      final bounds = _computeBounds(sidoFeatures, 'CTP_KOR_NM', province);
      setState(() => _polygons = polygons);
      if (bounds != null) _fitBounds(bounds);
    } else {
      final provinceCode = _getProvinceCode(province);
      final sggFeatures = _sggGeo!['features'] as List<dynamic>;
      final polygons = _buildPolygons(
        _kOverlayCity, sggFeatures, 'SIG_KOR_NM', city,
        provinceCode: provinceCode,
      );
      final bounds = _computeBounds(
        sggFeatures, 'SIG_KOR_NM', city,
        provinceCode: provinceCode,
      );
      setState(() => _polygons = polygons);
      if (bounds != null) _fitBounds(bounds);
    }
  }

  @override
  void didUpdateWidget(GoogleTripStep5Screen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedProvince != widget.selectedProvince ||
        oldWidget.selectedCity != widget.selectedCity) {
      _updateOverlays();
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  List<String> _availableCities(String province) {
    if (province == _kPlaceholder) return [_kPlaceholder];
    final list = _cities[province] ?? ['해당 시/군/구 없음'];
    return [_kPlaceholder, _kAllCities, ...list];
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
          GoogleMap(
            initialCameraPosition: _kKoreaOverview,
            polygons: _polygons,
            onMapCreated: (controller) {
              _mapController = controller;
              _updateOverlays();
            },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            scrollGesturesEnabled: true,
            zoomGesturesEnabled: true,
            rotateGesturesEnabled: false,
          ),
          Positioned(
            right: 14,
            top: 0,
            bottom: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildGlassButton(Icons.add, () {
                    _mapController?.animateCamera(CameraUpdate.zoomIn());
                  }),
                  const SizedBox(height: 8),
                  _buildGlassButton(Icons.remove, () {
                    _mapController?.animateCamera(CameraUpdate.zoomOut());
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
