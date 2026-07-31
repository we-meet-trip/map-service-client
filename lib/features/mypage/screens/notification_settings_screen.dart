import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/back_header.dart';
import '../../../core/state/user_repository.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            BackHeader(title: '알림 설정', onBack: () => context.pop()),
            const SizedBox(height: 20),
            ValueListenableBuilder<UserProfile>(
              valueListenable: UserRepository.instance.profile,
              builder: (context, profile, _) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(
                        '알림 설정',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.neutralScale[600],
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: profile.notificationsEnabled,
                        onChanged: (v) =>
                            UserRepository.instance.updateNotificationsEnabled(v),
                        activeThumbColor: Colors.white,
                        activeTrackColor: AppColors.secondaryScale[500],
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: AppColors.neutralScale[100],
                        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
