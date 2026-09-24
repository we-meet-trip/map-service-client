import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/starry_background.dart';

/// 여행 계획 탭의 첫 화면. 일정을 만드는 세 갈래를 고른다.
///
/// AI 추천은 외부 AI 로 여행 조건과 장소 정보를 보내고 호출마다 비용이 든다.
/// 직접 계획하기와 랜덤 여행은 AI 를 쓰지 않아 동의 없이 바로 시작한다.
class TripStartScreen extends StatelessWidget {
  /// AI 추천 마법사를 시작한다.
  final VoidCallback onStart;

  /// 지도에서 직접 장소를 찾아 일정을 짠다.
  final VoidCallback onPlan;

  /// 돌림판으로 여행지와 미션을 뽑는다.
  final VoidCallback onRandom;

  const TripStartScreen({
    super.key,
    required this.onStart,
    required this.onPlan,
    required this.onRandom,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StarryBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                const _SpeechBubble(),
                const SizedBox(height: 4),
                Transform.translate(
                  offset: const Offset(15, 0),
                  child: ExcludeSemantics(
                    child: SvgPicture.asset(
                      'assets/svg/character.svg',
                      width: 150,
                      height: 133,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _ChoiceButton(
                  icon: Icons.map_outlined,
                  title: '여행 일정 계획하기',
                  subtitle: '지도에서 장소를 찾아 직접 담아요',
                  onTap: onPlan,
                ),
                const SizedBox(height: 16),
                _ChoiceButton(
                  icon: Icons.auto_awesome_outlined,
                  title: '추천받기',
                  subtitle: 'AI가 조건에 맞는 코스를 짜 드려요',
                  onTap: onStart,
                ),
                const SizedBox(height: 16),
                _ChoiceButton(
                  icon: Icons.casino_outlined,
                  title: '랜덤으로 가기',
                  subtitle: '돌림판으로 여행지와 미션을 뽑아요',
                  onTap: onRandom,
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      // 반투명 카드 뒤로 배경 별이 비쳐 글머리표처럼 보이지 않게 흐린다.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: AppColors.gradientScale[300]!.withAlpha(0x4D),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.secondaryScale[300]!.withAlpha(0x80),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryScale[200]!.withAlpha(0x40),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withAlpha(0xCC),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Colors.white.withAlpha(0xB3),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
          '어떻게 떠나볼까요?',
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
