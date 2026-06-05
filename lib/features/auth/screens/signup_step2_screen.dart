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
      currentStep: 2,
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
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth * 0.4;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GenderButton(
                    label: '남성',
                    emoji: '👨',
                    width: w,
                    selected: _gender == '남성',
                    onTap: () => setState(() => _gender = _gender == '남성' ? null : '남성'),
                  ),
                  const SizedBox(width: 20),
                  _GenderButton(
                    label: '여성',
                    emoji: '👩',
                    width: w,
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

class _GenderButton extends StatelessWidget {
  const _GenderButton({
    required this.label,
    required this.emoji,
    required this.width,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String emoji;
  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: width,
        height: 120,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.secondaryScale[200]!.withAlpha(0x99)
                : AppColors.secondaryScale[200]!.withAlpha(0x4D),
            borderRadius: BorderRadius.circular(20),
            border: selected
                ? Border.all(color: AppColors.gradientScale[500]!, width: 1)
                : null,
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? AppColors.neutralScale[600]
                      : AppColors.neutralScale[400],
                ),
              ),
            ],
          ),
      ),
    );
  }
}
