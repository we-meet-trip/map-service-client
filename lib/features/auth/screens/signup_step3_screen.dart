import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/signup_step_scaffold.dart';
import '../widgets/interest_chip_selector.dart';
import '../../../common/constants/interests.dart';
import '../../../common/theme/app_colors.dart';
import '../../../core/state/user_repository.dart';

class SignupStep3Screen extends StatefulWidget {
  const SignupStep3Screen({super.key});

  @override
  State<SignupStep3Screen> createState() => _SignupStep3ScreenState();
}

class _SignupStep3ScreenState extends State<SignupStep3Screen> {
  List<String> _selectedInterests = [];

  @override
  Widget build(BuildContext context) {
    return SignupStepScaffold(
      title: '관심사를 선택해주세요',
      subtitle: '관심분야를 선택하시면 맞춤 여행 콘텐츠를 추천해드려요.',
      currentStep: 3,
      onBack: () => context.pop(),
      onNext: () {
        UserRepository.instance.updateInterests(_selectedInterests);
        context.go('/signup/complete');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '(선택)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.neutralScale[500],
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: InterestChipSelector(
              items: kInterestOptions,
              onChanged: (selected) => _selectedInterests = selected,
            ),
          ),
        ],
      ),
    );
  }
}
