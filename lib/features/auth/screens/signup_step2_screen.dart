import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/gender_choice_chip.dart';
import '../../../core/state/user_repository.dart';
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

  bool get _canProceed => _birthdate != null;

  @override
  Widget build(BuildContext context) {
    return SignupStepScaffold(
      title: '생년월일과 성별을 알려주세요',
      subtitle: '나랑 비슷한 사람들이 좋아하는 여행 콘텐츠를 추천드려요.',
      currentStep: 2,
      onBack: () => context.pop(),
      onNext: _canProceed
          ? () {
              UserRepository.instance.updateBirthGender(
                birthdate: _birthdate,
                gender: _gender,
              );
              context.push('/signup/step3');
            }
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '생년월일',
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
                    onTap: () => setState(() => _gender = _gender == '남성' ? null : '남성'),
                  ),
                  const SizedBox(width: 20),
                  GenderChoiceChip(
                    label: '여성',
                    emoji: '👩',
                    width: w,
                    height: 120,
                    selected: _gender == '여성',
                    onTap: () => setState(() => _gender = _gender == '여성' ? null : '여성'),
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
