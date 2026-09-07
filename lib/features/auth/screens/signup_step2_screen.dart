import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/gender_choice_chip.dart';
import '../../../core/state/user_repository.dart';
import '../../../core/state/service_consent_store.dart';
import '../widgets/birthdate_field.dart';
import '../widgets/signup_step_scaffold.dart';

class SignupStep2Screen extends StatefulWidget {
  const SignupStep2Screen({super.key});

  @override
  State<SignupStep2Screen> createState() => _SignupStep2ScreenState();
}

class _SignupStep2ScreenState extends State<SignupStep2Screen> {
  DateTime? _birthdate;
  String? _gender;

  bool get _canProceed => _birthdate != null && isAtLeast18(_birthdate!);

  @override
  Widget build(BuildContext context) {
    return SignupStepScaffold(
      title: '생년월일과 성별을 알려주세요',
      subtitle: '만 18세 이상 여부를 확인하기 위해 생년월일을 입력해주세요. 성별은 선택 항목입니다.',
      currentStep: 2,
      onBack: () => context.pop(),
      onNext: _canProceed
          ? () {
              UserRepository.instance.updateBirthGender(
                birthdate: _birthdate,
                gender: _gender,
                clearBirthdate: _birthdate == null,
                clearGender: _gender == null,
              );
              context.push('/signup/step3');
            }
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '생년월일 (필수)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.neutralScale[500],
            ),
          ),
          const SizedBox(height: 13),
          BirthdateField(
            value: _birthdate,
            onChanged: (date) => setState(() => _birthdate = date),
          ),
          if (_birthdate != null && !_canProceed)
            const Text('만 18세 미만은 가입할 수 없습니다.'),
          if (_birthdate != null)
            TextButton(
              onPressed: () => setState(() => _birthdate = null),
              child: const Text('생년월일 입력 취소'),
            ),
          const SizedBox(height: 45),
          Text(
            '성별 (선택)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.neutralScale[500],
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth * 0.4;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GenderChoiceChip(
                    label: '남성',
                    emoji: '👨',
                    width: w,
                    height: 120,
                    selected: _gender == '남성',
                    onTap: () =>
                        setState(() => _gender = _gender == '남성' ? null : '남성'),
                  ),
                  const SizedBox(width: 20),
                  GenderChoiceChip(
                    label: '여성',
                    emoji: '👩',
                    width: w,
                    height: 120,
                    selected: _gender == '여성',
                    onTap: () =>
                        setState(() => _gender = _gender == '여성' ? null : '여성'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
