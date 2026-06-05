import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../common/widgets/next_button.dart';
import '../../../core/router/app_router.dart';

class SignupCompleteScreen extends StatelessWidget {
  const SignupCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F0FA),
      body: SafeArea(
        child: Stack(
          children: [
            // 중앙 콘텐츠
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/svg/character.svg',
                    height: 180,
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    '가입을 축하합니다!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '나만의 여행 콘텐츠들을 추천받고\n빛나는 여정을 시작해보세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            // 하단 버튼
            Positioned(
              left: 24,
              right: 24,
              bottom: 42,
              child: NextButton(
                label: '나의 여정 시작하기',
                onPressed: () {
                  isAuthenticated.value = true;
                  context.go('/');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}