import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';
import 'signup_back_button.dart';
import 'signup_next_button.dart';

class SignupStepScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback onBack;
  final VoidCallback? onNext;

  const SignupStepScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    required this.onBack,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: SignupBackButton(onPressed: onBack),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.neutralScale[600],
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.neutralScale[500],
                  ),
                ),
              ],
              const SizedBox(height: 40),
              child,
              const Spacer(),
              SignupNextButton(onPressed: onNext),
              const SizedBox(height: 20),
            ],

          ),

        ),
      ),
    );
  }
}
