import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';
import 'trip_step_indicator.dart';

class TripStepHeader extends StatelessWidget {
  final int step;
  final String title;
  final String subtitle;
  final bool isNextEnabled;

  const TripStepHeader({
    super.key,
    required this.step,
    required this.title,
    required this.subtitle,
    this.isNextEnabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TripStepIndicator(currentStep: step, isNextEnabled: isNextEnabled),
        const SizedBox(height: 24),
        Text(
          title,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.neutralScale[600],
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: AppColors.neutralScale[300]),
        ),
      ],
    );
  }
}
