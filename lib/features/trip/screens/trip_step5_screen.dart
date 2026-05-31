import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../common/theme/app_colors.dart';

class TripStep5Screen extends StatefulWidget {
  const TripStep5Screen({super.key});

  @override
  State<TripStep5Screen> createState() => _TripStep5ScreenState();
}

class _TripStep5ScreenState extends State<TripStep5Screen> {
  String _selectedProvince = '강원도';
  String _selectedCity = '속초시';

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

  List<String> get _availableCities {
    return _cities[_selectedProvince] ?? ['해당 시/군/구 없음'];
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            _buildStepHeader(),
            const SizedBox(height: 16),
            _buildTitle(),
            const SizedBox(height: 32),
            _buildDropdowns(),
            const SizedBox(height: 20),
            _buildMapArea(),
            const SizedBox(height: 24),
            _buildNextButton(),
            const SizedBox(height: 12),
            _buildBackButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStepHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStepBadge(),
        _buildProgressDots(),
      ],
    );
  }

  Widget _buildStepBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(
          color: AppColors.primaryScale[400]!,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.diamond_outlined,
            size: 13,
            color: AppColors.primaryScale[400],
          ),
          const SizedBox(width: 5),
          Text(
            'STEP 05',
            style: TextStyle(
              color: AppColors.primaryScale[400],
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressDots() {
    return Row(
      children: List.generate(6, (index) {
        final isActive = index < 5;
        final isCurrent = index == 4;
        return Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? (isCurrent
                      ? AppColors.primaryScale[500]
                      : AppColors.primaryScale[200])
                  : Colors.transparent,
              border: Border.all(
                color: isActive
                    ? Colors.transparent
                    : AppColors.neutralScale[200]!,
                width: 1.5,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '어디로 떠나볼까요?',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.neutralScale[600],
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '당신의 여행이 시작될 출발지를 선택해주세요.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.neutralScale[300],
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdowns() {
    return Row(
      children: [
        Expanded(
          child: _buildDropdownField(
            label: '시/도',
            value: _selectedProvince,
            items: _provinces,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedProvince = value;
                  final cities = _cities[value];
                  _selectedCity = cities != null && cities.isNotEmpty
                      ? cities.first
                      : '';
                });
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildDropdownField(
            label: '시/군/구',
            value: _availableCities.contains(_selectedCity)
                ? _selectedCity
                : _availableCities.first,
            items: _availableCities,
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedCity = value);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.neutralScale[400],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.neutralScale[100]!),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.neutralScale[400],
                size: 22,
              ),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.neutralScale[600],
              ),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
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
      height: 340,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFFD8E8D0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // 카카오맵 SDK 영역 (추후 KakaoMap 위젯으로 교체)
          Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color(0xFFD8E8D0),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 48,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '카카오맵',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 지도 위 +/- 줌 버튼
          Positioned(
            right: 14,
            top: 0,
            bottom: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMapButton(Icons.add),
                  const SizedBox(height: 2),
                  _buildMapButton(Icons.remove),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapButton(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, size: 20, color: AppColors.neutralScale[500]),
    );
  }

  Widget _buildNextButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.gradientScale[200]!,
              AppColors.gradientScale[600]!,
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: ElevatedButton(
          onPressed: () => context.go('/trip/step6'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: const Text(
            '다음 단계로',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: TextButton(
        onPressed: () {
          // 이전 단계로 이동
        },
        child: Text(
          '← 이전 단계로 돌아가기',
          style: TextStyle(
            color: AppColors.neutralScale[400],
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
