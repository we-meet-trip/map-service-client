import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';

// 진행 도트 색상
final _kDotDone    = AppColors.secondaryScale[900]!; // 완료
final _kDotCurrent = AppColors.secondaryScale[200]!; // 진행중
final _kDotFuture  = AppColors.secondaryScale[0]!;   // 미진행

// STEP 배지 색상
final _kBadgeBg     = AppColors.secondaryScale[0]!;
final _kBadgeBorder = AppColors.primaryScale[100]!;
final _kBadgeText   = AppColors.secondaryScale[900]!;

class TripStepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final bool isNextEnabled;

  const TripStepIndicator({
    super.key,
    required this.currentStep,
    this.totalSteps = 5,
    this.isNextEnabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _StepBadge(step: currentStep),
        _StepDots(
          currentStep: currentStep,
          totalSteps: totalSteps,
          isNextEnabled: isNextEnabled,
        ),
      ],
    );
  }
}

class _StepBadge extends StatelessWidget {
  final int step;
  const _StepBadge({required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: _kBadgeBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBadgeBorder),
      ),
      child: Text(
        '✦  STEP ${step.toString().padLeft(2, '0')}',
        style: TextStyle(
          color: _kBadgeText,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final bool isNextEnabled;
  const _StepDots({
    required this.currentStep,
    required this.totalSteps,
    required this.isNextEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (i) {
        final Color color;
        final double size;
        if (i < currentStep - 1) {
          color = _kDotDone;    size = 7;
        } else if (i == currentStep - 1) {
          color = isNextEnabled ? _kDotDone : _kDotCurrent; size = 7;
        } else {
          color = _kDotFuture;  size = 7;
        }
        return Container(
          margin: const EdgeInsets.only(left: 6),
          width: size, height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        );
      }),
    );
  }
}
