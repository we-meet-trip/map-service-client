import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';
import '../../trip/widgets/trip_step_header.dart';
import '../../trip/widgets/trip_step_scaffold.dart';

class PlaceExploreStep2Screen extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onPrev;

  const PlaceExploreStep2Screen({
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
          step: 2,
          totalSteps: 2,
          title: '내가 선택한 장소',
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
