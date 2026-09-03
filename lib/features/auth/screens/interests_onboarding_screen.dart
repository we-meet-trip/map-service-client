import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../post_login_route.dart';

import '../../../common/constants/interests.dart';
import '../../../common/constants/trip_themes.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/next_button.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/user_api_service.dart';
import '../widgets/interest_chip_selector.dart';

/// 소셜 로그인으로 처음 들어온 사용자의 취향 수집 화면.
///
/// 이메일 가입은 단계 안에서 관심사·테마를 받지만, 소셜 로그인은 그 단계를
/// 거치지 않아 취향이 비어 있다. 첫 로그인 직후 한 번만 이 화면을 띄운다.
///
/// 이미 고른 값이 있으면 곧장 넘긴다 — 로그인할 때마다 다시 물으면 성가시다.
class InterestsOnboardingScreen extends StatefulWidget {
  const InterestsOnboardingScreen({super.key});

  @override
  State<InterestsOnboardingScreen> createState() =>
      _InterestsOnboardingScreenState();
}

class _InterestsOnboardingScreenState
    extends State<InterestsOnboardingScreen> {
  List<String> _interests = [];
  List<String> _themeLabels = [];
  bool _checking = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _skipIfAlreadyChosen();
  }

  Future<void> _skipIfAlreadyChosen() async {
    try {
      final profile = await UserApiService.instance.me();
      if (!mounted) return;
      if (profile.interests.isNotEmpty || profile.themes.isNotEmpty) {
        _leave();
        return;
      }
    } on ApiException {
      // 조회에 실패해도 화면은 보여 준다 — 고르고 저장할 때 다시 알린다.
    }
    if (!mounted) return;
    setState(() => _checking = false);
  }

  void _leave() {
    context.go(postLoginRoute(context));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await UserApiService.instance.update(
        interests: _interests,
        themes: themeIdsFromLabels(_themeLabels),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    _leave();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Text(
                '관심사를 선택해주세요',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.neutralScale[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '관심분야를 선택하시면 맞춤 여행 콘텐츠를 추천해드려요.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.neutralScale[500],
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InterestChipSelector(
                        items: kInterestOptions,
                        onChanged: (v) => _interests = v,
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
                      const SizedBox(height: 14),
                      InterestChipSelector(
                        items: kTripThemeLabels,
                        onChanged: (v) => _themeLabels = v,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              NextButton(
                label: _saving ? '저장하는 중…' : '시작하기',
                onPressed: _saving ? null : _save,
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _saving ? null : _leave,
                  child: Text(
                    '나중에 할게요',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.neutralScale[400]),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
