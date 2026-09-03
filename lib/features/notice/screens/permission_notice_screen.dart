import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/next_button.dart';
import '../../../data/local/permission_notice_store.dart';

/// 앱이 어떤 선택 권한을 왜 쓰는지 처음 한 번 알려 주는 화면.
///
/// 확인을 누르면 기기에 남겨 두고 다시 보여 주지 않는다.
class PermissionNoticeScreen extends StatelessWidget {
  const PermissionNoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bodyColor = AppColors.neutralScale[400];
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '접근 권한 안내',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutralScale[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'MAP 은 아래 권한을 선택으로 사용해요.\n각 기능을 쓰는 순간에만 허용을 물어봐요.',
                style: TextStyle(fontSize: 14, color: bodyColor, height: 1.5),
              ),
              const SizedBox(height: 32),
              const _PermissionItem(
                name: '위치',
                purpose: '현재 위치 날씨, 주변 이동수단, 길안내, 장소 인식',
              ),
              const _PermissionItem(
                name: '카메라',
                purpose: '장소 인식 촬영',
              ),
              const _PermissionItem(
                name: '마이크',
                purpose: '장소 인식 음성 질문',
              ),
              const SizedBox(height: 32),
              Text(
                '권한을 거부해도 해당 기능 외에는 그대로 이용할 수 있어요.\n'
                '허용한 권한은 설정 > 애플리케이션 > MAP > 권한 에서 '
                '언제든지 철회할 수 있어요.',
                style: TextStyle(fontSize: 13, color: bodyColor, height: 1.6),
              ),
              const Spacer(),
              NextButton(
                label: '확인했어요',
                onPressed: () async {
                  await PermissionNoticeStore.instance.confirm();
                  if (context.mounted) context.go('/');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionItem extends StatelessWidget {
  const _PermissionItem({required this.name, required this.purpose});

  final String name;
  final String purpose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.neutralScale[600],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              purpose,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.neutralScale[400],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
