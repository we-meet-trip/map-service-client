import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../common/theme/app_colors.dart';
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
      onBack: () => context.pop(),
      onNext: _canProceed ? () => context.push('/signup/step3') : null,
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
          Row(
            children: [
              _GenderButton(
                label: '남성',
                selected: _gender == '남성',
                onTap: () => setState(() => _gender = _gender == '남성' ? null : '남성'),
              ),
              const SizedBox(width: 12),
              _GenderButton(
                label: '여성',
                selected: _gender == '여성',
                onTap: () => setState(() => _gender = _gender == '여성' ? null : '여성'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GenderButton extends StatelessWidget {
  const _GenderButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryScale[500] : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.primaryScale[500]!
                  : AppColors.neutralScale[200]!,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: selected
                  ? AppColors.neutralScale[0]
                  : AppColors.neutralScale[400],
            ),
          ),
        ),
      ),
    );
  }
}
