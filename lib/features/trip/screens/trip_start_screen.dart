import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/starry_background.dart';

class TripStartScreen extends StatelessWidget {
  final VoidCallback onStart;
  const TripStartScreen({super.key, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StarryBackground(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(flex: 3),

            const _SpeechBubble(),
            const SizedBox(height: 4),

            Transform.translate(
              offset: const Offset(15, 0),
              child: GestureDetector(
                onTap: onStart,
                child: SvgPicture.asset(
                  'assets/svg/character.svg',
                  width: 176,
                  height: 156,
                ),
              ),
            ),

            const SizedBox(height: 28),

            Text(
              'TOUCH TO START',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 3.0,
                fontWeight: FontWeight.w500,
                color: Colors.white.withAlpha(153),
              ),
            ),

            const Spacer(flex: 4),
          ],
        ),
      ),
    );
  }
}

Path _buildBubblePath(Size size) {
  final w = size.width;
  final h = size.height;
  final bubbleH = h - 12.0;
  final r = bubbleH / 2;

  final tailRight = w * 0.177;
  final tailLeft  = w * 0.107;

  return Path()
    ..moveTo(r, 0)
    ..lineTo(w - r, 0)
    ..arcToPoint(Offset(w, r), radius: Radius.circular(r), clockwise: true)
    ..lineTo(w, bubbleH - r)
    ..arcToPoint(Offset(w - r, bubbleH), radius: Radius.circular(r), clockwise: true)
    ..lineTo(tailRight, bubbleH)
    ..cubicTo(w * 0.162, h * 0.885, w * 0.190, h * 0.987, w * 0.191, h)
    ..cubicTo(w * 0.190, h * 0.987, w * 0.120, h * 0.963, tailLeft, bubbleH)
    ..lineTo(r, bubbleH)
    ..arcToPoint(Offset(0, bubbleH - r), radius: Radius.circular(r), clockwise: true)
    ..lineTo(0, r)
    ..arcToPoint(Offset(r, 0), radius: Radius.circular(r), clockwise: true)
    ..close();
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BubblePainter(),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(28, 13, 28, 23),
        child: Text(
          '코스 추천 시작',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      _buildBubblePath(size),
      Paint()
        ..color = AppColors.secondaryScale[200]!.withAlpha(0x40)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_BubblePainter o) => false;
}
