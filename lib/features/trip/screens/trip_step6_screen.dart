import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';
import '../widgets/trip_step_header.dart';
import '../widgets/trip_step_scaffold.dart';

class TripStep6Screen extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onPrev;

  const TripStep6Screen({
    super.key,
    required this.onNext,
    required this.onPrev,
  });

  @override
  State<TripStep6Screen> createState() => _TripStep6ScreenState();
}

class _TripStep6ScreenState extends State<TripStep6Screen> {
  @override
  Widget build(BuildContext context) {
    return TripStepScaffold(
      onNext: widget.onNext,
      onPrev: widget.onPrev,
      children: [
        TripStepHeader(
          step: 6,
          title: '장소를 선택해 주세요',
          subtitle: '지도에서 방문하고 싶은 장소를 골라보세요.',
        ),
        const SizedBox(height: 24),
        Container(
          height: 380,
          decoration: BoxDecoration(
            color: AppColors.neutralScale[100],
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: AppColors.neutralScale[100],
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ],
    );
  }
}
