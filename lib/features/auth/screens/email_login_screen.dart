import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/next_button.dart';
import '../../../common/widgets/text_field.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/auth_api_service.dart';
import '../../../core/state/trip_repository.dart';

class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _emailError;
  String? _passwordError;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String v) =>
      RegExp(r'^[\w.+-]+@[\w-]+\.[a-z]{2,}$').hasMatch(v);

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _emailError = email.isEmpty
          ? '이메일을 입력해주세요.'
          : !_isValidEmail(email)
              ? '올바른 이메일 형식이 아닙니다.'
              : null;
      _passwordError = password.isEmpty
          ? '비밀번호를 입력해주세요.'
          : password.length < 8
              ? '비밀번호는 8자 이상이어야 합니다.'
              : null;
    });

    if (_emailError != null || _passwordError != null) return;

    setState(() => _loading = true);

    try {
      await AuthApiService.instance.login(email: email, password: password);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // 서버는 이메일과 비밀번호 중 무엇이 틀렸는지 가려 주지 않는다.
        // 가려 주면 어떤 이메일이 가입돼 있는지 알아낼 수 있기 때문이다.
        _passwordError = e.message;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _loading = false);

    if (TripRepository.instance.pendingTrip != null) {
      context.go('/trip');
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: AppColors.neutralScale[500]),
          onPressed: () => context.pop(),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          '이메일로 로그인',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppColors.neutralScale[600],
                          ),
                        ),
                        const SizedBox(height: 36),
                        AppTextField(
                          controller: _emailController,
                          labelText: '이메일',
                          hintText: 'example@email.com',
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          errorText: _emailError,
                          onChanged: (_) {
                            if (_emailError != null) setState(() => _emailError = null);
                          },
                        ),
                        const SizedBox(height: 28),
                        AppTextField(
                          controller: _passwordController,
                          labelText: '비밀번호',
                          hintText: '8자 이상 입력해주세요',
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          errorText: _passwordError,
                          onChanged: (_) {
                            if (_passwordError != null) setState(() => _passwordError = null);
                          },
                          onSubmitted: (_) => _submit(),
                        ),
                      ],
                    ),
                  ),
                ),
                NextButton(
                  label: _loading ? '로그인 중...' : '로그인',
                  onPressed: _loading ? null : _submit,
                ),
                const SizedBox(height: 42),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
