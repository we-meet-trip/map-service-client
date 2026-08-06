import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';
import '../../trip/widgets/trip_step_header.dart';
import '../../trip/widgets/trip_step_scaffold.dart';

class PlaceExploreStep1Screen extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onPrev;

  const PlaceExploreStep1Screen({
    super.key,
    required this.onNext,
    required this.onPrev,
  });

  @override
  State<PlaceExploreStep1Screen> createState() =>
      _PlaceExploreStep1ScreenState();
}

class _PlaceExploreStep1ScreenState extends State<PlaceExploreStep1Screen> {
  @override
  Widget build(BuildContext context) {
    return TripStepScaffold(
      onNext: widget.onNext,
      onPrev: widget.onPrev,
      children: [
        TripStepHeader(
          step: 1,
          title: '어디로 떠나볼까요?',
          subtitle: '원하는 장소 최소 3곳을 선택해주세요.',
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
