import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../common/theme/app_colors.dart';

class SearchStep1Screen extends StatefulWidget {
  const SearchStep1Screen({super.key});

  @override
  State<SearchStep1Screen> createState() => _SearchStep1ScreenState();
}

class _SearchStep1ScreenState extends State<SearchStep1Screen> {
  int _selectedIndex = 0;

  final List<_SearchOption> _options = const [
    _SearchOption(
      title: '완전 재탐색하기',
      subtitle: '완전히 새로운 일정으로 추천해요',
      iconData: Icons.refresh_rounded,
      iconBg: Color(0xFFEAD4FF),
      iconColor: Color(0xFFAD51FB),
    ),
    _SearchOption(
      title: 'AI 추천 장소 선택하기',
      subtitle: 'AI 추천 장소를 골라볼까요?',
      iconData: Icons.place_outlined,
      iconBg: Color(0xFFFFEDD5),
      iconColor: Color(0xFFF97316),
    ),
    _SearchOption(
      title: '직접 수정하기',
      subtitle: '장소를 직접 검색하고 수정해요',
      iconData: Icons.tune_rounded,
      iconBg: Color(0xFFDBEAFE),
      iconColor: Color(0xFF3B82F6),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── 스크롤 영역 ──
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 제목 ──
                Text(
                  '일정이 마음에 들지\n않으신가요?',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutralScale[600],
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '원하시는 추가 탐색 옵션을 선택해주세요.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.neutralScale[300],
                  ),
                ),
                const SizedBox(height: 36),

                // ── 옵션 카드 목록 ──
                ..._options.asMap().entries.map((entry) {
                  final i = entry.key;
                  final opt = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildOptionCard(i, opt),
                  );
                }),
              ],
            ),
          ),
        ),

        // ── 하단 고정 버튼 ──
        Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStartButton(context),
              const SizedBox(height: 10),
              _buildBackButton(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionCard(int index, _SearchOption opt) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFAF5FF)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFAD51FB)
                : AppColors.neutralScale[100]!,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFAD51FB).withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            // ── 아이콘 ──
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isSelected ? opt.iconBg : opt.iconBg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                opt.iconData,
                size: 24,
                color: isSelected
                    ? opt.iconColor
                    : opt.iconColor.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(width: 14),

            // ── 텍스트 ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    opt.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppColors.neutralScale[600]
                          : AppColors.neutralScale[300],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    opt.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? AppColors.neutralScale[300]
                          : AppColors.neutralScale[200],
                    ),
                  ),
                ],
              ),
            ),

            // ── 라디오 버튼 ──
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? const Color(0xFFAD51FB)
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFAD51FB)
                      : AppColors.neutralScale[200]!,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.circle, size: 8, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton(BuildContext context) {
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
          onPressed: () {
            if (_selectedIndex == 0) {
              // 완전 재탐색 → step5로
              context.go('/trip');
            }
            // 다른 옵션은 추후 연결
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: const Text(
            '재탐색 시작하기  →',
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

  Widget _buildBackButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: () => context.go('/trip/step6'),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.neutralScale[100]!),
          backgroundColor: const Color(0xFFFDFDFE),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        child: Text(
          '←  경로로 돌아가기',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.neutralScale[400],
          ),
        ),
      ),
    );
  }
}

class _SearchOption {
  final String title;
  final String subtitle;
  final IconData iconData;
  final Color iconBg;
  final Color iconColor;

  const _SearchOption({
    required this.title,
    required this.subtitle,
    required this.iconData,
    required this.iconBg,
    required this.iconColor,
  });
}
