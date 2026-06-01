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

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BubblePainter(),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(28, 13, 28, 21),
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
    final paint = Paint()
      ..color = AppColors.secondaryScale[200]!.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;

    final bubbleH = size.height - 10.0;
    final radius = bubbleH / 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, bubbleH),
        Radius.circular(radius),
      ),
      paint,
    );

    final tailPath = Path()
      ..moveTo(size.width * 0.32, bubbleH)
      ..lineTo(size.width * 0.38, size.height)
      ..lineTo(size.width * 0.46, bubbleH)
      ..close();
    canvas.drawPath(tailPath, paint);
  }

  @override
  bool shouldRepaint(_BubblePainter o) => false;
}
