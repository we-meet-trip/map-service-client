import 'package:flutter/material.dart';
import 'star_painter.dart';

class StarryBackground extends StatelessWidget {
  final Widget child;

  const StarryBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [
            Color(0xFF5522AC),
            Color(0xFF1B0B33),
          ],
          stops: [0.0, 0.91],
        ),
      ),
      child: Stack(
        children: [
          CustomPaint(painter: StarPainter(), size: Size.infinite),
          child,
        ],
      ),
    );
  }
}
