import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/signup_step_scaffold.dart';

class SignupStep3Screen extends StatefulWidget {
  const SignupStep3Screen({super.key});

  @override
  State<SignupStep3Screen> createState() => _SignupStep3ScreenState();
}

class _SignupStep3ScreenState extends State<SignupStep3Screen> {
  bool get _canProceed => false; // 콘텐츠 추가 후 조건 구현

  @override
  Widget build(BuildContext context) {
    return SignupStepScaffold(
      title: '관심사를 선택해주세요',
      subtitle: '관심분야를 선택하시면 맞춤 여행 콘텐츠를 추천해드려요.',
      onBack: () => context.pop(),
      onNext: _canProceed ? () => context.go('/signup/complete') : null,
      child: const SizedBox.shrink(),
    );
  }
}
