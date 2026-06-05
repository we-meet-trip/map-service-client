import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';

class SignupBackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const SignupBackButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        color: AppColors.neutralScale[500],
        onPressed: onPressed,
      ),
    );
  }
}
