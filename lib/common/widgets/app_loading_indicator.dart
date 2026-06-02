import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 공통 로딩 스피너 (Subtract.svg 기반)
/// 36px 링에 angular gradient 적용, 회전 애니메이션
class AppLoadingIndicator extends StatefulWidget {
  final double size;

  const AppLoadingIndicator({super.key, this.size = 36});

  @override
  State<AppLoadingIndicator> createState() => _AppLoadingIndicatorState();
}

class _AppLoadingIndicatorState extends State<AppLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.rotate(
        angle: _ctrl.value * 2 * math.pi,
        child: CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _SpinnerPainter(),
        ),
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // SVG: 외부 반지름 17.524, 내부 반지름 12.985 → 링 두께 ≈ 4.54px (35px 기준)
    final strokeWidth = size.width * (4.54 / 35.05);
    final radius = size.width / 2 - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = SweepGradient(
        // SVG: from solid purple(#A551EF) → near-transparent light purple
        colors: [
          AppColors.secondaryScale[500]!,                       // 진한 보라 (헤드)
          AppColors.secondaryScale[0]!.withValues(alpha: 0.85), // 연한 보라 (테일)
        ],
      ).createShader(rect);

    canvas.drawArc(rect, 0, 2 * math.pi, false, paint);
  }

  @override
  bool shouldRepaint(_SpinnerPainter o) => false;
}
