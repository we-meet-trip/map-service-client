import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 앱 전역에서 쓰는 확인 팝업 공통 컴포넌트.
/// 흰 배경 라운드 카드 + 취소/확인 2버튼 레이아웃.
/// [onConfirm]이 null이면 확인 버튼이 비활성(회색) 상태로 렌더된다.
class AppConfirmDialog extends StatelessWidget {
  final Widget content;
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;

  const AppConfirmDialog({
    super.key,
    required this.content,
    required this.confirmLabel,
    this.cancelLabel = '취소',
    this.onCancel,
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onConfirm != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            content,
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel ?? () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.neutralScale[200]!),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      cancelLabel,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.neutralScale[400],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: enabled
                          ? LinearGradient(colors: [
                              AppColors.gradientScale[200]!,
                              AppColors.gradientScale[600]!,
                            ])
                          : null,
                      color: enabled ? null : AppColors.neutralScale[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      onPressed: onConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        confirmLabel,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: enabled ? Colors.white : AppColors.neutralScale[300],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
