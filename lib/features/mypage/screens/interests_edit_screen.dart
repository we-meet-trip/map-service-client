import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../common/constants/interests.dart';
import '../../../common/constants/trip_themes.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/back_header.dart';
import '../../../common/widgets/next_button.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/user_api_service.dart';
import '../../../core/state/user_repository.dart';
import '../../auth/widgets/interest_chip_selector.dart';

/// 관심사·테마 설정.
///
/// 서버에 보관된 값을 열 때 읽어 오고, 저장할 때 되돌려 보낸다. 앱 메모리에만
/// 두면 앱을 껐다 켰을 때 고른 것이 사라진다.
///
/// 이 화면은 취향만 보낸다 — 프로필 화면이 다루는 값을 함께 보내면 그쪽에서
/// 바꾼 내용을 덮어쓴다.
class InterestsEditScreen extends StatefulWidget {
  const InterestsEditScreen({super.key});

  @override
  State<InterestsEditScreen> createState() => _InterestsEditScreenState();
}

class _InterestsEditScreenState extends State<InterestsEditScreen> {
  late List<String> _selectedInterests =
      UserRepository.instance.profile.value.interests;
  late List<String> _selectedThemeLabels =
      themeLabelsFromIds(UserRepository.instance.profile.value.themes);

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await UserApiService.instance.me();
      if (!mounted) return;
      // 서버 값을 화면과 앱 양쪽에 반영해 둔다.
      UserRepository.instance.updateInterests(profile.interests);
      UserRepository.instance.updateThemes(profile.themes);
      setState(() {
        _selectedInterests = profile.interests;
        _selectedThemeLabels = themeLabelsFromIds(profile.themes);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final themes = themeIdsFromLabels(_selectedThemeLabels);
    try {
      await UserApiService.instance.update(
        interests: _selectedInterests,
        themes: themes,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (!mounted) return;
    UserRepository.instance.updateInterests(_selectedInterests);
    UserRepository.instance.updateThemes(themes);
    setState(() => _saving = false);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BackHeader(title: '관심사 설정', onBack: () => context.pop()),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InterestChipSelector(
                            key: ValueKey(_selectedInterests),
                            items: kInterestOptions,
                            initialSelected: _selectedInterests,
                            onChanged: (v) => _selectedInterests = v,
                          ),
                          const SizedBox(height: 28),
                          Text(
                            '여행 테마',
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
                              color: AppColors.neutralScale[400],
                            ),
                          ),
                          const SizedBox(height: 14),
                          InterestChipSelector(
                            key: ValueKey(_selectedThemeLabels),
                            items: kTripThemeLabels,
                            initialSelected: _selectedThemeLabels,
                            onChanged: (v) => _selectedThemeLabels = v,
                          ),
                        ],
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: NextButton(
                label: _saving ? '저장하는 중…' : '저장',
                onPressed: _loading || _saving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
