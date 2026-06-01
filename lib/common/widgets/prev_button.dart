import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PrevButton extends StatelessWidget {
  final VoidCallback onPressed;
  const PrevButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0x99FFFFFF),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: const Color(0xCCFFFFFF),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.neutralScale[600]!.withAlpha(0x0F),
                offset: const Offset(0, 2.27),
                blurRadius: 9.09,
              ),
            ],
          ),
          child: Text(
            '← 이전 단계로 돌아가기',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.neutralScale[400],
            ),
          ),
        ),
      ),
    );
  }
}
