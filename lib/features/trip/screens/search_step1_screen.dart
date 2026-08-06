import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/next_button.dart';
import '../../../common/widgets/prev_button.dart';
import 'trip_regenerate_screen.dart';

class SearchStep1Screen extends StatefulWidget {
  const SearchStep1Screen({super.key});

  @override
  State<SearchStep1Screen> createState() => _SearchStep1ScreenState();
}

class _SearchStep1ScreenState extends State<SearchStep1Screen> {
  int _selectedIndex = 0;

  final List<_SearchOption> _options = [
    _SearchOption(
      title: '완전 재탐색하기',
      subtitle: '완전히 새로운 일정으로 추천해요',
      iconData: Icons.refresh_rounded,
      iconBg: AppColors.secondaryScale[200]!,
      iconColor: AppColors.secondaryScale[500]!,
    ),
    _SearchOption(
      title: 'AI 추천 장소 선택하기',
      subtitle: 'AI 추천 장소를 골라볼까요?',
      iconData: Icons.place_outlined,
      iconBg: const Color(0xFFFFEDD5),
      iconColor: const Color(0xFFF97316),
    ),
    _SearchOption(
      title: '직접 수정하기',
      subtitle: '장소를 직접 검색하고 수정해요',
      iconData: Icons.tune_rounded,
      iconBg: const Color(0xFFDBEAFE),
      iconColor: const Color(0xFF3B82F6),
      disabled: true,
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
              NextButton(
                label: '재탐색 시작하기  →',
                onPressed: () {
                  if (_selectedIndex == 1) {
                    context.go('/trip/place-explore/step1');
                  } else {
                    tripRetrialNotifier.value++;
                    context.go('/trip');
                  }
                },
              ),
              const SizedBox(height: 10),
              PrevButton(
                onPressed: () => context.go('/trip'),
                label: '← 경로로 돌아가기',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionCard(int index, _SearchOption opt) {
    final isSelected = _selectedIndex == index;
    final disabled = opt.disabled;

    return GestureDetector(
      onTap: disabled ? null : () => setState(() => _selectedIndex = index),
      child: Opacity(
        opacity: disabled ? 0.45 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.secondaryScale[0] : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppColors.secondaryScale[500]!
                  : AppColors.neutralScale[100]!,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.secondaryScale[500]!.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: AppColors.neutralScale[600]!.withAlpha(0x0A),
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
                  color: isSelected
                      ? opt.iconBg
                      : opt.iconBg.withValues(alpha: 0.5),
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
                    Row(
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
                        if (disabled) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.neutralScale[100],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '준비 중',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.neutralScale[300],
                              ),
                            ),
                          ),
                        ],
                      ],
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
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.secondaryScale[500]!
                        : AppColors.neutralScale[200]!,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.secondaryScale[500],
                          ),
                        ),
                      )
                    : null,
              ),
            ],
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
  final bool disabled;

  const _SearchOption({
    required this.title,
    required this.subtitle,
    required this.iconData,
    required this.iconBg,
    required this.iconColor,
    this.disabled = false,
  });
}
