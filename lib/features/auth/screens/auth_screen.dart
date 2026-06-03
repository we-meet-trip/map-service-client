import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/starry_background.dart';
import '../widgets/kakao_login_button.dart';
import '../widgets/email_login_button.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      body: StarryBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 274),
              Padding(
                padding: EdgeInsets.only(left: width * 55 / 402),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '나만의 별빛 여정✨',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 24,
                        color: AppColors.neutralScale[0],
                        shadows: const [
                          Shadow(
                            color: Color(0xFFC98CFF),
                            blurRadius: 5,
                            offset: Offset(0, 0),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'MAP',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 40,
                            color: AppColors.gradientScale[200],
                            shadows: [
                              Shadow(
                                color: AppColors.gradientScale[300]!,
                                blurRadius: 7,
                                offset: Offset(0, 0),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        SvgPicture.asset('assets/svg/character.svg'),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 462),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: width * 40 / 402),
                child: Column(
                  children: [
                    const KakaoLoginButton(),
                    const SizedBox(height: 12),
                    const EmailLoginButton(),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => context.push('/signup/step1'),
                          child: const Text('간편 회원가입'),
                        ),
                        const Text('|'),
                        TextButton(
                          onPressed: () {},
                          child: const Text('문의하기'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 20),
            ],
          ),
        ),
      ),
    );
  }
}
