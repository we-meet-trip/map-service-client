import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/star_painter.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // gradient 배경
          Container(
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
          ),
          // 별
          CustomPaint(
            painter: StarPainter(),
            size: Size.infinite,
          ),
          // 나머지 UI
          SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('로그인 페이지입니다.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/signup/step1'),
                    child: const Text('회원가입'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}