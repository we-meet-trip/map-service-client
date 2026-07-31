import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 성별 선택 등에 쓰는 선택형 칩. [emoji]가 있으면 이모지+라벨 세로 배치,
/// 없으면 라벨만 표시한다.
class GenderChoiceChip extends StatelessWidget {
  const GenderChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.emoji,
    this.width,
    this.height,
    this.borderRadius = 20,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? emoji;
  final double? width;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: width,
        height: height,
        padding: height == null ? const EdgeInsets.symmetric(vertical: 14) : null,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.secondaryScale[200]!.withAlpha(0x99)
              : AppColors.secondaryScale[200]!.withAlpha(0x4D),
          borderRadius: BorderRadius.circular(borderRadius),
          border: selected
              ? Border.all(color: AppColors.gradientScale[500]!, width: 1)
              : null,
        ),
        alignment: Alignment.center,
        child: emoji != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji!, style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: selected ? AppColors.neutralScale[600] : AppColors.neutralScale[400],
                    ),
                  ),
                ],
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.neutralScale[600] : AppColors.neutralScale[400],
                ),
              ),
      ),
    );
  }
}
