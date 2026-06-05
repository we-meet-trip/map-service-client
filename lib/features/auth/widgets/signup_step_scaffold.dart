import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';
import 'signup_back_button.dart';
import 'step_dots.dart';
import '../../../common/widgets/next_button.dart';

class SignupStepScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback onBack;
  final VoidCallback? onNext;
  final int currentStep;
  final int totalSteps;

  const SignupStepScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    required this.onBack,
    this.onNext,
    required this.currentStep,
    this.totalSteps = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: SignupBackButton(onPressed: onBack),
        actions: [
          Padding(
            padding: const EdgeInsets.only(top: 24, right: 24),
            child: StepDots(
              currentStep: currentStep,
              totalSteps: totalSteps,
              dotDone: AppColors.secondaryScale[900]!,
              dotCurrent: AppColors.secondaryScale[200]!,
              dotFuture: AppColors.secondaryScale[0]!,
            ),
          ),
        ],
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
              NextButton(onPressed: onNext),
              const SizedBox(height: 42),
            ],

          ),

        ),
      ),
    );
  }
}
