import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../common/widgets/next_button.dart';
import '../../../core/router/app_router.dart';
import '../../../common/theme/app_colors.dart';

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
                  Transform.translate(
                    offset: const Offset(15, 0),
                    child: SvgPicture.asset(
                      'assets/svg/character_shadow.svg',
                      height: 136,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    '가입을 축하합니다!',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.neutralScale[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '나만의 여행 콘텐츠들을 추천받고\n빛나는 여정을 시작해보세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.neutralScale[400],
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 60),
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