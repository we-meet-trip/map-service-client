import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/signup_step_scaffold.dart';
import '../widgets/interest_chip_selector.dart';
import '../../../common/theme/app_colors.dart';

const _kInterests = [
  '당일치기 🚗', '맛집 🍜', '카페 ☕', '자연 🌿', '공원 🌳', '골목 🏘️',
  '힐링 🧘', '역사 🏛️', '문화 🎭', '쇼핑 🛍️', '마켓 🛒', '사진 명소 📸',
  '테마파크 🎢', '전시 🖼️', '축제 🎉', '해변 🏖️', '공연 🎵', '스포츠 관람 🏟️',
  '브런치 🥞', '서점 📚', '오락 🎮',
];

class SignupStep3Screen extends StatelessWidget {
  const SignupStep3Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return SignupStepScaffold(
      title: '관심사를 선택해주세요',
      subtitle: '관심분야를 선택하시면 맞춤 여행 콘텐츠를 추천해드려요.',
      currentStep: 3,
      onBack: () => context.pop(),
      onNext: () => context.go('/signup/complete'),
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
              items: _kInterests,
              onChanged: (_) {},
            ),
          ),
        ],
      ),
    );
  }
}
