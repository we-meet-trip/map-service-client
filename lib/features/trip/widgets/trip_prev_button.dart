import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';

class TripPrevButton extends StatelessWidget {
  final VoidCallback onPressed;
  const TripPrevButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        // 그림자는 ClipRRect 바깥에서 렌더
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: const Color(0x0F222124), // #222124 at 6%
              offset: const Offset(0, 2.27),
              blurRadius: 9.09,
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
            child: GestureDetector(
              onTap: onPressed,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 11),
                decoration: BoxDecoration(
                  color: const Color(0x99FFFFFF), // white 60%
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color: const Color(0xCCFFFFFF), // white 80%
                    width: 1,
                  ),
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
          ),
        ),
      ),
    );
  }
}
