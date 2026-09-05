import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/theme/app_icons.dart';
import '../../../common/widgets/app_confirm_dialog.dart';
import '../../../common/widgets/back_header.dart';
import '../../../common/widgets/gender_choice_chip.dart';
import '../../../common/widgets/named_address_prompt.dart';
import '../../../common/widgets/text_field.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/auth_api_service.dart' show AuthApiService;
import '../../../core/api/user_api_service.dart' show UserApiService;
import '../../../core/state/auth_store.dart';
import '../../../core/state/user_repository.dart';
import '../../auth/widgets/birthdate_field.dart';
import '../widgets/profile_avatar.dart';

class ProfileEditScreen extends StatelessWidget {
  const ProfileEditScreen({super.key});

  Future<void> _pickImage(BuildContext context) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) {
      UserRepository.instance.updateProfileImage(picked.path);
    }
  }

  /// 이름을 바꾼다.
  ///
  /// 로그인한 상태면 서버에 먼저 반영한다. 기기에만 적어 두면 다음 로그인이나
  /// 앱 재시작 때 서버에서 받아 온 이름이 덮어써서 방금 바꾼 이름이 사라진다.
  ///
  /// 로그인 전에는 서버에 보낼 곳이 없으므로 기기에만 적는다 — 가입 화면을
  /// 거치기 전에도 이 화면을 쓸 수 있다.
  Future<void> _saveNickname(BuildContext context, String nickname) async {
    final trimmed = nickname.trim();
    if (trimmed.isEmpty || trimmed == UserRepository.instance.profile.value.nickname) {
      return;
    }
    if (!AuthStore.instance.isLoggedIn.value) {
      UserRepository.instance.updateNickname(trimmed);
      return;
    }
    try {
      final updated = await UserApiService.instance.update(nickname: trimmed);
      UserRepository.instance.updateNickname(updated.nickname);
      // 보관소의 이름은 앱을 다시 켰을 때 화면이 처음 그리는 값이다. 함께
      // 고치지 않으면 재시작 직후 잠깐 옛 이름이 보인다.
      await AuthStore.instance.updateNickname(updated.nickname);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _editText(
    BuildContext context, {
    required String title,
    required String initialValue,
    required ValueChanged<String> onSave,
    TextInputType? keyboardType,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppConfirmDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutralScale[600],
                ),
              ),
              const SizedBox(height: 20),
              AppTextField(
                controller: controller,
                hintText: title,
                maxLength: 30,
                keyboardType: keyboardType,
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          cancelLabel: '취소',
          confirmLabel: '저장',
          onConfirm: controller.text.trim().isNotEmpty
              ? () => Navigator.of(ctx).pop(controller.text.trim())
              : null,
        ),
      ),
    );
    if (result != null && result.isNotEmpty) onSave(result);
  }

  Future<void> _editHomeAddress(BuildContext context) async {
    final address = await context.push<String>('/address-search');
    if (address != null && address.isNotEmpty) {
      UserRepository.instance.updateHomeAddress(address);
    }
  }

  Future<void> _addOtherAddress(BuildContext context) async {
    final result = await promptAddNamedAddress(context);
    if (result != null) {
      UserRepository.instance.addOtherAddress(result);
    }
  }

  Future<void> _editOtherAddress(BuildContext context, int index) async {
    final result = await promptAddNamedAddress(context);
    if (result != null) {
      UserRepository.instance.updateOtherAddress(index, result);
    }
  }

  Future<void> _editBirthdate(BuildContext context, DateTime? current) async {
    final picked = await BirthdateField.pickDate(context, initial: current);
    UserRepository.instance.updateBirthGender(birthdate: picked);
  }

  Future<void> _editGender(BuildContext context, String? current) async {
    String? selected = current;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppConfirmDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '성별',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutralScale[600],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GenderChoiceChip(
                      label: '남성',
                      borderRadius: 12,
                      selected: selected == '남성',
                      onTap: () => setDialogState(() => selected = '남성'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GenderChoiceChip(
                      label: '여성',
                      borderRadius: 12,
                      selected: selected == '여성',
                      onTap: () => setDialogState(() => selected = '여성'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          cancelLabel: '취소',
          confirmLabel: '저장',
          onConfirm: selected != null ? () => Navigator.of(ctx).pop(selected) : null,
        ),
      ),
    );
    if (result != null) {
      UserRepository.instance.updateBirthGender(gender: result);
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ValueListenableBuilder<UserProfile>(
          valueListenable: UserRepository.instance.profile,
          builder: (context, profile, _) {
            void editNickname() => _editText(
                  context,
                  title: '이름',
                  initialValue: profile.nickname,
                  onSave: (v) => _saveNickname(context, v),
                );
            return Column(
              children: [
                BackHeader(title: '프로필 설정', onBack: () => context.pop()),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => _pickImage(context),
                          child: ProfileAvatar(imagePath: profile.profileImagePath, size: 110, color: AppColors.avatarColorOf(profile.id)),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: editNickname,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                profile.displayName,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.neutralScale[600],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.edit, size: 16, color: AppColors.neutralScale[300]),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(height: 9, width: double.infinity, color: AppColors.mypageDivider),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                          child: Row(
                            children: [
                              Text(
                                '내 정보 수정',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.neutralScale[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        _InfoRow(
                          label: '이름',
                          value: profile.nickname.isEmpty ? null : profile.nickname,
                          onTap: editNickname,
                        ),
                        _InfoRow(
                          label: '영문이름',
                          value: profile.englishName,
                          onTap: () => _editText(
                            context,
                            title: '영문이름',
                            initialValue: profile.englishName ?? '',
                            onSave: (v) => UserRepository.instance.updateEnglishName(v),
                          ),
                        ),
                        _InfoRow(
                          label: '생년월일',
                          value: profile.birthdate != null ? _fmtDate(profile.birthdate!) : null,
                          onTap: () => _editBirthdate(context, profile.birthdate),
                        ),
                        _InfoRow(
                          label: '휴대폰 번호',
                          value: profile.phone,
                          showEditButton: true,
                          onTap: () => _editText(
                            context,
                            title: '휴대폰 번호',
                            initialValue: profile.phone ?? '',
                            keyboardType: TextInputType.phone,
                            onSave: (v) => UserRepository.instance.updatePhone(v),
                          ),
                        ),
                        _InfoRow(
                          label: '이메일',
                          value: profile.email,
                          showEditButton: true,
                          onTap: () => _editText(
                            context,
                            title: '이메일',
                            initialValue: profile.email ?? '',
                            keyboardType: TextInputType.emailAddress,
                            onSave: (v) => UserRepository.instance.updateEmail(v),
                          ),
                        ),
                        _InfoRow(
                          label: '집주소',
                          value: profile.homeAddress,
                          showEditButton: true,
                          onTap: () => _editHomeAddress(context),
                        ),
                        for (var i = 0; i < profile.otherAddresses.length; i++)
                          _InfoRow(
                            label: i == 0 ? '주소' : '',
                            value: '${profile.otherAddresses[i].name} · ${profile.otherAddresses[i].address}',
                            onTap: () => _editOtherAddress(context, i),
                            trailing: GestureDetector(
                              onTap: () => UserRepository.instance.removeOtherAddress(i),
                              child: Icon(Icons.close_rounded, size: 16, color: AppColors.neutralScale[300]),
                            ),
                          ),
                        _InfoRow(
                          label: profile.otherAddresses.isEmpty ? '주소' : '',
                          value: null,
                          onTap: () => _addOtherAddress(context),
                        ),
                        _InfoRow(
                          label: '성별',
                          value: profile.gender,
                          onTap: () => _editGender(context, profile.gender),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => _confirmWithdraw(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '탈퇴하기',
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
          },
        ),
      ),
    );
  }

  void _confirmWithdraw(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AppConfirmDialog(
        content: Text(
          '정말 탈퇴하시겠어요?\n탈퇴 시 모든 정보가 삭제됩니다.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: AppColors.neutralScale[600], height: 1.5),
        ),
        cancelLabel: '취소',
        confirmLabel: '탈퇴하기',
        onConfirm: () {
          Navigator.of(ctx).pop();
          _withdraw(context);
        },
      ),
    );
  }

  /// 탈퇴를 서버에 알리고 화면을 마이페이지로 되돌린다.
  ///
  /// 성공했을 때만 화면을 옮긴다. 실패한 채로 옮기면 계정이 남아 있는데도
  /// 지워진 것처럼 보인다.
  Future<void> _withdraw(BuildContext context) async {
    try {
      await AuthApiService.instance.withdraw();
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('탈퇴가 완료되었어요.')),
    );
    context.go('/mypage');
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.showEditButton = false,
    this.trailing,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;
  final bool showEditButton;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 84,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.tabBarUnselected,
                ),
              ),
            ),
            Expanded(
              child: hasValue
                  ? Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.neutralScale[600],
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 14, color: AppColors.blueScale[500]),
                        const SizedBox(width: 2),
                        Text(
                          '추가',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.blueScale[500],
                          ),
                        ),
                      ],
                    ),
            ),
            if (trailing != null)
              trailing!
            else if (showEditButton && hasValue)
              Container(
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
                  '수정',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutralScale[400],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
