import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../common/widgets/next_button.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/auth_api_service.dart';
import '../../../core/state/user_repository.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/theme/app_text_styles.dart';
import '../post_login_route.dart';

/// 가입 마지막 화면.
///
/// 앞 단계들이 모아 둔 값을 여기서 **한 번에** 서버로 보낸다. 단계마다 나눠
/// 보내면 중간에 그만뒀을 때 반쪽짜리 계정이 남는다.
///
/// 가입에 실패하면 화면을 넘기지 않고 사유를 알린다 — 실패한 채로 넘어가면
/// 로그인한 것처럼 보이다가 다음 요청에서야 아니라는 것이 드러난다.
class SignupCompleteScreen extends StatefulWidget {
  const SignupCompleteScreen({super.key});

  @override
  State<SignupCompleteScreen> createState() => _SignupCompleteScreenState();
}

class _SignupCompleteScreenState extends State<SignupCompleteScreen> {
  bool _submitting = false;

  Future<void> _finish() async {
    final repo = UserRepository.instance;
    final email = repo.signUpEmail;
    final password = repo.signUpPassword;
    if (email == null || password == null) {
      // 계정 단계를 거치지 않고 들어온 경우. 그 단계로 되돌린다.
      context.go('/signup/step4');
      return;
    }

    setState(() => _submitting = true);
    final profile = repo.profile.value;
    try {
      await AuthApiService.instance.signUp(
        email: email,
        password: password,
        nickname: profile.nickname,
        birthDate: profile.birthdate,
        gender: profile.gender,
        interests: profile.interests,
        themes: profile.themes,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (!mounted) return;
    // 보낸 뒤에는 기기에 비밀번호를 남기지 않는다.
    repo.signUpEmail = null;
    repo.signUpPassword = null;
    setState(() => _submitting = false);
    context.go(postLoginRoute(context));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.signupCompleteBackground,
      body: SafeArea(
        child: Stack(
          children: [
            // 중앙 콘텐츠
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 15),
                    child: SvgPicture.asset(
                      'assets/svg/character_shadow.svg',
                      height: 136,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    '가입을 축하합니다!',
                    style: AppTextStyles.title2,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '나만의 여행 콘텐츠들을 추천받고\n빛나는 여정을 시작해보세요.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body7Gray.copyWith(height: 1.6),
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
                label: _submitting ? '가입하는 중…' : '나의 여정 시작하기',
                onPressed: _submitting ? null : _finish,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
