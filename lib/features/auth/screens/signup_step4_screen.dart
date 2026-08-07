import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/text_field.dart';
import '../../../core/state/user_repository.dart';
import '../widgets/signup_step_scaffold.dart';

/// 가입 마지막 단계 — 로그인에 쓸 계정 정보.
///
/// 앞 단계들은 취향을 받고, 여기서 계정을 만든다. 이 값이 없으면 서버에
/// 가입 자체를 요청할 수 없다.
///
/// 여기서는 입력만 받고 보내지 않는다. 실제 가입 요청은 완료 화면이
/// 앞 단계에서 모은 값과 함께 한 번에 보낸다 — 중간에 끊겨도 반쪽짜리
/// 계정이 남지 않는다.
class SignupStep4Screen extends StatefulWidget {
  const SignupStep4Screen({super.key});

  @override
  State<SignupStep4Screen> createState() => _SignupStep4ScreenState();
}

class _SignupStep4ScreenState extends State<SignupStep4Screen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String v) =>
      RegExp(r'^[\w.+-]+@[\w-]+\.[a-z]{2,}$').hasMatch(v);

  /// 서버가 받는 비밀번호 하한과 같은 값. 여기서 먼저 막아야 왕복 없이 알린다.
  static const _minPasswordLength = 8;

  bool get _canProceed {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    return _isValidEmail(email) &&
        password.length >= _minPasswordLength &&
        password == _confirmController.text;
  }

  void _validate() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    setState(() {
      _emailError = email.isEmpty
          ? null
          : _isValidEmail(email)
              ? null
              : '올바른 이메일 형식이 아닙니다.';
      _passwordError = password.isEmpty
          ? null
          : password.length < _minPasswordLength
              ? '비밀번호는 8자 이상이어야 합니다.'
              : null;
      _confirmError = _confirmController.text.isEmpty
          ? null
          : password == _confirmController.text
              ? null
              : '비밀번호가 서로 달라요.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SignupStepScaffold(
      title: '로그인에 쓸 계정을 만들어요',
      subtitle: '다음에 다시 들어올 때 이 정보로 로그인해요.',
      currentStep: 4,
      totalSteps: 4,
      onBack: () => context.pop(),
      onNext: _canProceed
          ? () {
              final repo = UserRepository.instance;
              repo.signUpEmail = _emailController.text.trim();
              repo.signUpPassword = _passwordController.text;
              context.go('/signup/complete');
            }
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(
            controller: _emailController,
            hintText: '이메일 입력',
            errorText: _emailError,
            onChanged: (_) => _validate(),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _passwordController,
            hintText: '비밀번호 입력 (8자 이상)',
            errorText: _passwordError,
            obscureText: true,
            onChanged: (_) => _validate(),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _confirmController,
            hintText: '비밀번호 다시 입력',
            errorText: _confirmError,
            obscureText: true,
            onChanged: (_) => _validate(),
          ),
          const SizedBox(height: 12),
          Text(
            '가입하면 앞에서 고른 관심사와 테마가 함께 저장돼요.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.neutralScale[400],
            ),
          ),
        ],
      ),
    );
  }
}
