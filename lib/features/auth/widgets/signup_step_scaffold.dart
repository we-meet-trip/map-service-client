import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';
import 'signup_back_button.dart';
import 'signup_next_button.dart';

class SignupStepScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback onBack;
  final VoidCallback? onNext;

  const SignupStepScaffold({
    super.key,
    required this.title,
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
              const SizedBox(height: 32),
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
