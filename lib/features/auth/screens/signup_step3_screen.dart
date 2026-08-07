import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/signup_step_scaffold.dart';
import '../widgets/interest_chip_selector.dart';
import '../../../common/constants/interests.dart';
import '../../../common/constants/trip_themes.dart';
import '../../../common/theme/app_colors.dart';
import '../../../core/state/user_repository.dart';

class SignupStep3Screen extends StatefulWidget {
  const SignupStep3Screen({super.key});

  @override
  State<SignupStep3Screen> createState() => _SignupStep3ScreenState();
}

class _SignupStep3ScreenState extends State<SignupStep3Screen> {
  List<String> _selectedInterests = [];

  /// 고른 테마의 화면 표기. 보낼 때 코드값으로 바꾼다 — 여행 계획 화면이
  /// 서버에 보내는 값과 같아야 추천에 그대로 쓸 수 있다.
  List<String> _selectedThemeLabels = [];

  @override
  Widget build(BuildContext context) {
    return SignupStepScaffold(
      title: '관심사를 선택해주세요',
      subtitle: '관심분야를 선택하시면 맞춤 여행 콘텐츠를 추천해드려요.',
      currentStep: 3,
      totalSteps: 4,
      onBack: () => context.pop(),
      onNext: () {
        UserRepository.instance.updateInterests(_selectedInterests);
        UserRepository.instance
            .updateThemes(themeIdsFromLabels(_selectedThemeLabels));
        context.push('/signup/step4');
      },
      child: Expanded(
        child: SingleChildScrollView(
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
              const SizedBox(height: 28),
              Text(
                '어떤 여행을 좋아하세요?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutralScale[600],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '여행 일정을 만들 때 기본으로 쓰여요.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.neutralScale[500],
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: InterestChipSelector(
                  items: kTripThemeLabels,
                  onChanged: (selected) => _selectedThemeLabels = selected,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
