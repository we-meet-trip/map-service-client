import 'package:flutter/material.dart';

class StarPainter extends CustomPainter {
  const StarPainter();

  static const _stars = [
    (Offset(0.78, 0.17), 1.0),
    (Offset(0.35, 0.15), 1.2),
    (Offset(0.17, 0.18), 2.0),
    (Offset(0.77, 0.45), 1.0),
    (Offset(0.62, 0.52), 0.8),
    (Offset(0.24, 0.55), 2.2),
    (Offset(0.17, 0.58), 1.0),
    (Offset(0.82, 0.69), 0.8),
    (Offset(0.73, 0.74), 2.0),
    (Offset(0.21, 0.83), 0.7),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final (pos, starSize) in _stars) {
      // glow
      canvas.drawCircle(
        Offset(size.width * pos.dx, size.height * pos.dy),
        starSize * 2,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      // 별 본체
      canvas.drawCircle(
        Offset(size.width * pos.dx, size.height * pos.dy),
        starSize,
        Paint()..color = const Color(0xFFFDFDFE),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}