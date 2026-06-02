import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/theme/app_icons.dart';
import '../widgets/trip_step_header.dart';
import '../widgets/trip_step_scaffold.dart';

class TripStep5Screen extends StatelessWidget {
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

  static const _kPlaceholder = '선택';

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

  /// 시/도가 선택되지 않았으면 ['선택'], 선택됐으면 ['선택', ...실제 목록]
  List<String> _availableCities(String province) {
    if (province == _kPlaceholder) return [_kPlaceholder];
    final list = _cities[province] ?? ['해당 시/군/구 없음'];
    return [_kPlaceholder, ...list];
  }

  bool get _canProceed =>
      selectedProvince != _kPlaceholder && selectedCity != _kPlaceholder;

  @override
  Widget build(BuildContext context) {
    final cities = _availableCities(selectedProvince);
    final effectiveCity = cities.contains(selectedCity) ? selectedCity : _kPlaceholder;

    return TripStepScaffold(
      onNext: _canProceed ? onNext : null,
      onPrev: onPrev,
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
                value: selectedProvince,
                items: [_kPlaceholder, ..._provinces],
                onChanged: (v) {
                  if (v == null) return;
                  // 시/도 변경 시 시/군/구를 '선택'으로 리셋
                  onLocationChanged(v, _kPlaceholder);
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
                  if (v != null) onLocationChanged(selectedProvince, v);
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
          // ── 지도 영역 (KakaoMap SDK 연결 예정) ──
          Container(color: const Color(0xFFDDE8DD)),
          // ── 글라스 +/- 버튼 ──
          Positioned(
            right: 14,
            top: 0,
            bottom: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildGlassButton(Icons.add),
                  const SizedBox(height: 8),
                  _buildGlassButton(Icons.remove),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton(IconData icon) {
    return ClipOval(
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
    );
  }
}
