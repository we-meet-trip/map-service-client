import 'package:flutter/material.dart';

import '../../../common/theme/app_colors.dart';

class BboxOverlay extends StatelessWidget {
  final List<double> bbox; // [x1, y1, x2, y2] 픽셀 좌표
  final String label;

  const BboxOverlay({super.key, required this.bbox, required this.label});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _BboxPainter(
            bbox: bbox,
            label: label,
            screenSize: Size(constraints.maxWidth, constraints.maxHeight),
          ),
        );
      },
    );
  }
}

class _BboxPainter extends CustomPainter {
  final List<double> bbox;
  final String label;
  final Size screenSize;

  _BboxPainter({
    required this.bbox,
    required this.label,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bbox.length < 4) return;

    // YOLO 좌표(원본 이미지 픽셀) → 화면 비율로 변환
    // 원본 이미지 크기를 모르므로 bbox가 0~1 정규화 값이라고 가정
    // 만약 실제 픽셀 좌표라면 서버에서 정규화해서 보내야 함
    final x1 = bbox[0] * size.width;
    final y1 = bbox[1] * size.height;
    final x2 = bbox[2] * size.width;
    final y2 = bbox[3] * size.height;

    final rect = Rect.fromLTRB(x1, y1, x2, y2);

    final boxPaint = Paint()
      ..color = AppColors.primaryScale[400]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawRect(rect, boxPaint);

    // 모서리 강조
    _drawCorners(canvas, rect);

    // 레이블 배경
    final labelBgPaint = Paint()
      ..color = AppColors.primaryScale[500]!.withValues(alpha: 0.85);
    final labelRect = Rect.fromLTWH(x1, y1 - 28, (label.length * 9.0) + 16, 26);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        labelRect,
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      ),
      labelBgPaint,
    );

    // 레이블 텍스트
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x1 + 8, y1 - 23));
  }

  void _drawCorners(Canvas canvas, Rect rect) {
    const len = 16.0;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final corners = [
      [rect.topLeft, Offset(rect.left + len, rect.top), Offset(rect.left, rect.top + len)],
      [rect.topRight, Offset(rect.right - len, rect.top), Offset(rect.right, rect.top + len)],
      [rect.bottomLeft, Offset(rect.left + len, rect.bottom), Offset(rect.left, rect.bottom - len)],
      [rect.bottomRight, Offset(rect.right - len, rect.bottom), Offset(rect.right, rect.bottom - len)],
    ];

    for (final c in corners) {
      canvas.drawLine(c[0], c[1], paint);
      canvas.drawLine(c[0], c[2], paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BboxPainter old) =>
      old.bbox != bbox || old.label != label;
}
