import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';

// 임시 버튼
class SignupNextButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;

  const SignupNextButton({
    super.key,
    required this.onPressed,
    this.label = '다음 단계로',
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryScale[700],
          disabledBackgroundColor: AppColors.neutralScale[100],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(40),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: enabled
                ? AppColors.neutralScale[0]
                : AppColors.neutralScale[300],
          ),
        ),
      ),
    );
  }
}
