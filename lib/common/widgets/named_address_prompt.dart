import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../../core/state/user_repository.dart';
import 'app_confirm_dialog.dart';
import 'text_field.dart';

/// 주소 검색 → 이름 지정 흐름을 거쳐 [NamedAddress]를 반환한다.
/// 검색/이름 지정 중 취소하면 null을 반환한다.
Future<NamedAddress?> promptAddNamedAddress(BuildContext context) async {
  final address = await context.push<String>('/address-search');
  if (address == null || address.isEmpty || !context.mounted) return null;

  final nameController = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    useRootNavigator: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AppConfirmDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📍 이름을 정해주세요.',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.neutralScale[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              address,
              style: TextStyle(fontSize: 14, color: AppColors.neutralScale[300]),
            ),
            const SizedBox(height: 24),
            AppTextField(
              controller: nameController,
              hintText: '예: 회사, 학교',
              maxLength: 10,
              onChanged: (_) => setDialogState(() {}),
            ),
          ],
        ),
        cancelLabel: '취소',
        confirmLabel: '등록하기',
        onConfirm: nameController.text.trim().isNotEmpty
            ? () => Navigator.of(ctx).pop(nameController.text.trim())
            : null,
      ),
    ),
  );
  nameController.dispose();

  if (name == null || name.isEmpty) return null;
  return NamedAddress(name: name, address: address);
}
