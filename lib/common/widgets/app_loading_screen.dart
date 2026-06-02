import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';
import 'app_loading_indicator.dart';
import 'starry_background.dart';

/// 공통 로딩 화면
/// AI 생성 등 시간이 걸리는 작업 사이에 표시
/// [future]가 주어지면 완료될 때까지 대기 (최소 [minDuration])
class AppLoadingScreen extends StatefulWidget {
  final Future<void>? future;
  final Duration minDuration;
  final VoidCallback? onComplete;

  const AppLoadingScreen({
    super.key,
    this.future,
    this.minDuration = const Duration(seconds: 2),
    this.onComplete,
  });

  @override
  State<AppLoadingScreen> createState() => _AppLoadingScreenState();
}

class _AppLoadingScreenState extends State<AppLoadingScreen> {
  @override
  void initState() {
    super.initState();
    _startLoading();
  }

  Future<void> _startLoading() async {
    // future와 최소 대기시간을 동시에 실행, 둘 다 완료되면 진행
    await Future.wait([
      widget.future ?? Future<void>.value(),
      Future<void>.delayed(widget.minDuration),
    ]);
    if (mounted) widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StarryBackground(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(flex: 3),

            // 말풍선
            _buildSpeechBubble(),
            const SizedBox(height: 4),

            // 캐릭터
            Transform.translate(
              offset: const Offset(15, 0),
              child: SvgPicture.asset(
                'assets/svg/character.svg',
                width: 176,
                height: 156,
              ),
            ),

            const SizedBox(height: 28),

            // 로딩 스피너
            const AppLoadingIndicator(size: 36),

            const Spacer(flex: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeechBubble() {
    return CustomPaint(
      painter: _BubblePainter(),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(20, 13, 20, 23),
        child: Text(
          '잠시만 기다려주세요 · · ·',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── 말풍선 경로 ──────────────────────────────────────────────

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
