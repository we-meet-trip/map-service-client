import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 목록이 비었거나 불러오지 못했을 때 보여 주는 안내.
///
/// 같은 생김새가 이미 네 화면에 복사돼 있었고, 나머지 화면은 글자 한 줄만
/// 두거나 아무것도 두지 않았다. 그래서 어떤 빈 화면은 안내가 있고 어떤
/// 빈 화면은 그냥 흰 여백이었다.
///
/// [onRetry] 를 주면 '불러오지 못한 상태'로 그린다. 빈 목록과 실패를
/// 같은 문구로 보여 주면 사용자가 다시 시도할 생각을 못 한다.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.onRetry,
    this.retryLabel = '다시 시도',
    this.action,
  });

  final IconData icon;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  /// 빈 상태에서 권하는 다음 행동. 실패 상태에는 쓰지 않는다.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    // 폭을 채우지 않으면 부모가 start 정렬일 때 내용이 제 너비만 차지해
    // 화면 왼쪽으로 치우친다. 호출부가 Center 로 감싸는 것을 잊어도
    // 가운데 오도록 여기서 폭을 채운다.
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppColors.neutralScale[200]),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body7Gray.copyWith(height: 1.5),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: Text(retryLabel)),
          ] else if (action != null) ...[
            const SizedBox(height: 24),
            action!,
          ],
        ],
      ),
    );
  }
}
