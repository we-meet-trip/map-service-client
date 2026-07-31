import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/theme/app_icons.dart';
import '../../../core/state/user_repository.dart';
import '../widgets/profile_avatar.dart';

class MypageScreen extends StatelessWidget {
  const MypageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top + 24,
            20,
            0,
          ),
          child: ValueListenableBuilder<UserProfile>(
            valueListenable: UserRepository.instance.profile,
            builder: (context, profile, _) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ProfileAvatar(imagePath: profile.profileImagePath, size: 60),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '안녕하세요!',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.tripAccentPurple,
                          ),
                        ),
                        const SizedBox(height: 2),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: profile.nickname.isEmpty ? '여행자' : profile.nickname,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.neutralScale[600],
                                ),
                              ),
                              TextSpan(
                                text: ' 님',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.neutralScale[400],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/mypage/edit'),
                    child: Container(
                      height: 22,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.neutralScale[0]!.withAlpha(140),
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neutralScale[600]!.withAlpha(15),
                            blurRadius: 9,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '내 정보 수정',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutralScale[500],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 28),
        _MenuItem(label: '관심사 설정', onTap: () => context.push('/mypage/interests')),
        _MenuItem(label: '알림 설정', onTap: () => context.push('/mypage/notifications')),
        Container(height: 9, width: double.infinity, color: AppColors.mypageDivider),
        const _MenuItem(label: '공지/이벤트'),
        const _MenuItem(label: '고객센터'),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => _showComingSoon(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '로그아웃',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.savedBadgeFar,
                    ),
                  ),
                  AppIcon(SvgIcons.chevronRightThin, size: 12, color: AppColors.savedBadgeFar),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('준비 중인 기능이에요.')),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.neutralScale[600],
            ),
          ),
          const Spacer(),
          AppIcon(SvgIcons.chevronRightThin, size: 16, color: AppColors.neutralScale[600]),
        ],
      ),
    );
    return onTap == null ? content : GestureDetector(onTap: onTap, child: content);
  }
}
