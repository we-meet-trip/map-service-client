import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../common/theme/app_colors.dart';
import '../widgets/star_painter.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final width = mq.size.width;
    final height = mq.size.height;
    final topInset = mq.padding.top;

    const designWidth = 402.0;
    const designHeight = 1096.0;

    final scale = height / designHeight;

    final leftPadding = width * (55 / designWidth);
    final horizontalPadding = width * (40 / designWidth);
    final topSpacer = (273.5 * scale - topInset).clamp(0.0, double.infinity);
    final bottomSpacer = (793.5 - 273.5 - 58) * scale;

    return Scaffold(
      body: Container(
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
        child: Stack(
          children: [
            CustomPaint(
              painter: StarPainter(),
              size: Size.infinite,
            ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: topSpacer),
                  Padding(
                    padding: EdgeInsets.only(left: leftPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('나만의 별빛 여정✨',
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: 24,
                            color: AppColors.neutralScale[0],
                            shadows: [
                              Shadow(
                                color: Color(0xFFC98CFF),
                                blurRadius: 5,
                                offset: Offset(0, 0),
                              ),
                            ],
                          ),),
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
                            SizedBox(width: 10),
                            SvgPicture.asset('assets/svg/character.svg'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: bottomSpacer),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Column(
                      children: [
                        ElevatedButton(
                          onPressed: () {},
                          child: const Text('카카오로 계속하기'),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {},
                          child: const Text('이메일로 계속하기'),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () => context.go('/signup/step1'),
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
                  SizedBox(height: 20 * scale),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
