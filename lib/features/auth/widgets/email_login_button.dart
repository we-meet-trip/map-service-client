import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';

class EmailLoginButton extends StatelessWidget {
  const EmailLoginButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 296,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(227.27),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF222124).withOpacity(0.06),
            offset: const Offset(0, 2.27),
            blurRadius: 9.09,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(227.27),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 9.09, sigmaY: 9.09),
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neutralScale[0]!.withOpacity(0.20),
              foregroundColor: AppColors.neutralScale[0],
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(227.27),
              ),
            ),
            child: Text(
              '이메일로 계속하기',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.neutralScale[0],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
