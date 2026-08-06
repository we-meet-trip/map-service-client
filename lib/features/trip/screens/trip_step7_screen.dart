import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';
import '../widgets/trip_step_header.dart';
import '../widgets/trip_step_scaffold.dart';

class TripStep7Screen extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onPrev;

  const TripStep7Screen({
    super.key,
    required this.onNext,
    required this.onPrev,
  });

  @override
  Widget build(BuildContext context) {
    return TripStepScaffold(
      onNext: onNext,
      onPrev: onPrev,
      children: [
        TripStepHeader(
          step: 7,
          title: '선택한 장소를 확인해요',
          subtitle: '선택하신 장소 목록을 확인해 주세요.',
        ),
        const SizedBox(height: 24),
        Container(
          height: 480,
          decoration: BoxDecoration(
            color: AppColors.neutralScale[100],
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ],
    );
  }
}
