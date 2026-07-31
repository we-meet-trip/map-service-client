import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../common/constants/interests.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/back_header.dart';
import '../../../common/widgets/next_button.dart';
import '../../../core/state/user_repository.dart';
import '../../auth/widgets/interest_chip_selector.dart';

class InterestsEditScreen extends StatefulWidget {
  const InterestsEditScreen({super.key});

  @override
  State<InterestsEditScreen> createState() => _InterestsEditScreenState();
}

class _InterestsEditScreenState extends State<InterestsEditScreen> {
  late List<String> _selectedInterests = UserRepository.instance.profile.value.interests;

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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                child: InterestChipSelector(
                  items: kInterestOptions,
                  initialSelected: _selectedInterests,
                  onChanged: (selected) => _selectedInterests = selected,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: NextButton(
                label: '저장',
                onPressed: () {
                  UserRepository.instance.updateInterests(_selectedInterests);
                  context.pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
