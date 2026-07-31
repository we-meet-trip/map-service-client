import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../common/widgets/text_field.dart';
import '../../../core/state/user_repository.dart';
import '../widgets/signup_step_scaffold.dart';

class SignupStep1Screen extends StatefulWidget {
  const SignupStep1Screen({super.key});

  @override
  State<SignupStep1Screen> createState() => _SignupStep1ScreenState();
}

class _SignupStep1ScreenState extends State<SignupStep1Screen> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {
      if (value.isEmpty) {
        _errorText = null;
      } else if (value.length < 2 || value.length > 8) {
        _errorText = '2자 이상 8자 이하로 입력해주세요.';
      } else {
        _errorText = null;
      }
    });
  }

  bool get _canProceed =>
      _controller.text.length >= 2 &&
      _controller.text.length <= 8 &&
      _errorText == null;

  @override
  Widget build(BuildContext context) {
    return SignupStepScaffold(
      title: '닉네임을 입력해주세요',
      currentStep: 1,
      onBack: () => context.pop(),
      onNext: _canProceed
          ? () {
              UserRepository.instance.updateNickname(_controller.text);
              context.push('/signup/step2');
            }
          : null,
      child: AppTextField(
        controller: _controller,
        hintText: '닉네임 입력',
        errorText: _errorText,
        onChanged: _onChanged,
      ),
    );
  }
}
