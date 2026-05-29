import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/birthdate_field.dart';
import '../widgets/signup_step_scaffold.dart';

class SignupStep2Screen extends StatefulWidget {
  const SignupStep2Screen({super.key});

  @override
  State<SignupStep2Screen> createState() => _SignupStep2ScreenState();
}

class _SignupStep2ScreenState extends State<SignupStep2Screen> {
  DateTime? _birthdate;

  bool get _canProceed => _birthdate != null;

  @override
  Widget build(BuildContext context) {
    return SignupStepScaffold(
      title: '생년월일과 성별을 알려주세요',
      subtitle: '나랑 비슷한 사람들이 좋아하는 여행 콘텐츠를 추천드려요.',
      onBack: () => context.pop(),
      onNext: _canProceed ? () => context.push('/signup/step3') : null,
      child: BirthdateField(
        value: _birthdate,
        onChanged: (date) => setState(() => _birthdate = date),
      ),
    );
  }
}
