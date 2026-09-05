import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/utils/support_mail.dart';
import '../../../common/widgets/starry_background.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/kakao_login_flow.dart';
import '../widgets/kakao_login_button.dart';
import '../widgets/email_login_button.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _kakaoBusy = false;

  /// 이번 카카오 요청을 가리키는 값. 되돌아온 주소가 이 값을 그대로 달고
  /// 와야 내가 시작한 로그인으로 인정한다.
  String _newState() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  Future<void> _kakaoLogin() async {
    if (_kakaoBusy) return;
    setState(() => _kakaoBusy = true);
    try {
      await KakaoLoginFlow.instance.run(_newState());
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _kakaoBusy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (!mounted) return;
    setState(() => _kakaoBusy = false);
    // 카카오로 처음 들어온 사용자는 취향을 고르는 단계를 거치지 않는다.
    // 그 자리를 한 번 채우게 하고, 이미 고른 사용자는 곧장 넘긴다.
    context.go('/signup/interests');
  }

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
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Text(
                          '나만의 별빛 여정',
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
                        Positioned(
                          right: -16,
                          top: -10,
                          child: SvgPicture.asset(
                            'assets/svg/glitter.svg',
                            width: 24,
                            height: 24,
                          ),
                        ),
                      ],
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
                        SvgPicture.asset('assets/svg/character.svg', height: 40),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 462),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: width * 55 / 402),
                child: Column(
                  children: [
                    KakaoLoginButton(
                      onPressed: _kakaoBusy ? () {} : _kakaoLogin,
                    ),
                    const SizedBox(height: 12),
                    EmailLoginButton(
                      onPressed: () => context.push('/auth/email'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => context.push('/signup/step1'),
                          child: Text(
                              '간편 회원가입',
                              style: TextStyle(
                                color: AppColors.background,
                                fontWeight: FontWeight.w400,
                                fontSize: 12,
                              ),
                          ),
                        ),
                        const Text('|',
                          style: TextStyle(
                            color: AppColors.background,
                            fontWeight: FontWeight.w100,
                            fontSize: 12,
                          ),
                        ),
                        TextButton(
                          onPressed: () => launchSupportMail(
                            subject: '[MAP 문의]',
                          ),
                          child: Text(
                              '문의하기',
                              style: TextStyle(
                                color: AppColors.background,
                                fontWeight: FontWeight.w400,
                                fontSize: 12,
                              )
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 100),
            ],
          ),
        ),
      ),
    );
  }
}
