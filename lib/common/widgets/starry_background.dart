import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'star_painter.dart';

class StarryBackground extends StatelessWidget {
  final Widget child;

  const StarryBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // 이 배경을 쓰는 화면은 전부 어둡다. 상태바 글자 색을 바꾸지 않으면
    // 시각·배터리가 검정으로 남아 어두운 보라 위에서 읽히지 않는다.
    // 밝은 화면으로 넘어가면 AnnotatedRegion 이 사라져 자동으로 되돌아온다.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: SizedBox.expand(
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.0,
              colors: [Color(0xFF5522AC), Color(0xFF1B0B33)],
              stops: [0.0, 0.91],
            ),
          ),
          child: Stack(
            children: [
              const Positioned.fill(child: CustomPaint(painter: StarPainter())),
              Positioned.fill(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
