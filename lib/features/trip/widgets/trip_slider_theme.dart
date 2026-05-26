import 'package:flutter/material.dart';

const kSliderActive   = Color(0xFF8D46ED);
const kSliderInactive = Color(0xFFF2EDF5);
const _kBorder        = Color(0xFF6012DF);
const _kFill          = Color(0xFFFCFCFD);
// 트랙 높이 6px × 3 = 직경 18px → 반지름 9
const _kRadius        = 9.0;

SliderThemeData tripSliderTheme(BuildContext context) =>
    SliderTheme.of(context).copyWith(
      activeTrackColor: kSliderActive,
      inactiveTrackColor: kSliderInactive,
      trackHeight: 6,
      rangeThumbShape: const _TripThumbShape(),
      rangeTickMarkShape: const RoundRangeSliderTickMarkShape(tickMarkRadius: 0),
      overlayColor: Colors.transparent,
      thumbColor: kSliderActive,
    );

class _TripThumbShape extends RangeSliderThumbShape {
  const _TripThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(_kRadius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    bool isDiscrete = false,
    bool isEnabled = false,
    bool isOnTop = false,
    required SliderThemeData sliderTheme,
    TextDirection? textDirection,
    Thumb? thumb,
    bool? isPressed,
  }) {
    final c = context.canvas;
    // 보라색 외원 (테두리 역할)
    c.drawCircle(center, _kRadius, Paint()..color = _kBorder);
    // 흰색 내원  (테두리 두께 = 3px)
    c.drawCircle(center, _kRadius - 3, Paint()..color = _kFill);
  }
}
