import 'package:flutter/material.dart';

class StepDots extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final bool isNextEnabled;
  final Color dotDone;
  final Color dotCurrent;
  final Color dotFuture;
  final double dotSize;

  const StepDots({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.isNextEnabled = false,
    required this.dotDone,
    required this.dotCurrent,
    required this.dotFuture,
    this.dotSize = 7,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (i) {
        final Color color;
        if (i < currentStep - 1) {
          color = dotDone;
        } else if (i == currentStep - 1) {
          color = isNextEnabled ? dotDone : dotCurrent;
        } else {
          color = dotFuture;
        }
        return Container(
          margin: const EdgeInsets.only(left: 6),
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        );
      }),
    );
  }
}
