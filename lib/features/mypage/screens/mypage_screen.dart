import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../common/utils/support_mail.dart';
import '../../../core/api/auth_api_service.dart';
import '../../../core/state/auth_store.dart';
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
                  ProfileAvatar(imagePath: profile.profileImagePath, size: 60, color: AppColors.avatarColorOf(profile.id)),
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
                                text: profile.displayName,
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
        Container(height: 9, width: double.infinity, color: AppColors.mypageDivider),
        _MenuItem(label: '고객센터', onTap: () => _openSupportMail(context)),
        _MenuItem(label: '약관 및 정책', onTap: () => _showPolicies(context)),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Align(
            alignment: Alignment.centerRight,
            // 로그인 여부에 따라 할 일이 달라진다. 로그인하지 않았는데
            // 로그아웃만 보이면 들어갈 길이 화면에서 사라진다.
            child: ValueListenableBuilder<bool>(
              valueListenable: AuthStore.instance.isLoggedIn,
              builder: (context, loggedIn, _) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  if (!loggedIn) {
                    context.push('/auth');
                    return;
                  }
                  await AuthApiService.instance.logout();
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      loggedIn ? '로그아웃' : '로그인',
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
        ),
      ],
    );
  }

  static Future<void> _openSupportMail(BuildContext context) async {
    final opened = await launchSupportMail(subject: '[MAP 문의]');
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('메일 앱을 열 수 없어요. $supportEmail 로 보내 주세요.')),
      );
    }
  }

  /// 약관 문서 목록. 항목을 고르면 브라우저로 연다.
  static void _showPolicies(BuildContext context) {
    const docs = {
      '개인정보처리방침': 'privacy.html',
      '이용약관': 'terms.html',
      '위치기반서비스 이용약관': 'location-terms.html',
    };
    showDialog<void>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('약관 및 정책'),
        children: [
          for (final e in docs.entries)
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(dialogContext);
                launchUrl(
                  Uri.parse('https://mapcenter-b59ca.web.app/legal/${e.value}'),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(e.key, style: const TextStyle(fontSize: 15)),
              ),
            ),
        ],
      ),
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
    // 빈 여백까지 눌리게 한다. 기본 설정으로는 글자와 화살표 위만 반응해,
    // 줄의 가운데를 눌러도 아무 일이 없는 것처럼 보인다.
    return onTap == null
        ? content
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: content,
          );
  }
}
