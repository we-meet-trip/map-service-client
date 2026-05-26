import 'package:flutter/material.dart';

// 진행 도트 색상
const _kDotDone    = Color(0xFF5C198A); // 완료
const _kDotCurrent = Color(0xFFEAD4FF); // 진행중
const _kDotFuture  = Color(0xFFF2EDF5); // 미진행

// STEP 배지 색상
const _kBadgeBg     = Color(0xFFF4EEFE);
const _kBadgeBorder = Color(0xFFCFBEFB);
const _kBadgeText   = Color(0xFF5422AC);

class TripStepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final bool isNextEnabled;

  const TripStepIndicator({
    super.key,
    required this.currentStep,
    this.totalSteps = 7,
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
        style: const TextStyle(
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
          color = isNextEnabled ? _kDotDone : _kDotCurrent; size = 8;
        } else {
          color = _kDotFuture;  size = 6;
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
