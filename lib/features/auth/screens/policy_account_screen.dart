import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/theme/app_text_styles.dart';
import '../../../common/theme/app_icons.dart';
import '../../../common/widgets/app_confirm_dialog.dart';
import '../../../common/widgets/app_loading_indicator.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/auth_api_service.dart';
import '../../../core/api/service_consent_api_service.dart';
import '../../../core/api/user_api_service.dart';
import '../../../core/state/auth_store.dart';
import '../../../core/state/service_consent_store.dart';

/// Independent account-only surface; no MainLayout, map, chat or recommendation provider.
class PolicyAccountScreen extends StatefulWidget {
  const PolicyAccountScreen({super.key});
  @override
  State<PolicyAccountScreen> createState() => _PolicyAccountScreenState();
}

class _PolicyAccountScreenState extends State<PolicyAccountScreen> {
  DateTime? _birth;
  bool _busy = true;
  String? _message;
  final _session = AuthStore.instance.sessionVersion;
  bool get _current => mounted && _session == AuthStore.instance.sessionVersion;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await UserApiService.instance.me();
      if (_current) setState(() => _birth = user.birthDate);
    } catch (_) {
      if (_current) setState(() => _message = '생년월일을 조회하지 못했어요. 다시 시도해주세요.');
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  Future<void> _correctBirth() async {
    if (_busy || !_current) return;
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: '정확한 생년월일을 선택해주세요',
    );
    if (date == null || !_current) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final user = await UserApiService.instance.update(birthDate: date);
      if (!_current) return;
      final store = ServiceConsentStore.instance;
      store.invalidate();
      ServiceConsentApiService.instance.bind(store);
      await store.refresh(force: true);
      if (_current) {
        setState(() {
          _birth = user.birthDate;
          _message = '생년월일을 저장했습니다. 이용 조건을 다시 확인해주세요.';
        });
      }
    } on ApiException catch (e) {
      if (_current) setState(() => _message = e.message);
    } catch (_) {
      if (_current) setState(() => _message = '정정 결과를 확인하지 못했어요. 다시 조회해주세요.');
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw() async {
    if (_busy || !_current) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AppConfirmDialog(
        confirmLabel: '탈퇴하기',
        onCancel: () => Navigator.pop(context, false),
        onConfirm: () => Navigator.pop(context, true),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('계정을 탈퇴할까요?', style: AppTextStyles.body2),
            const SizedBox(height: 12),
            Text(
              '계정·프로필·본인 일정과 추천 결과·본인이 작성한 채팅 내용이 삭제됩니다. '
              '다른 참여자가 작성한 메시지는 보존되고, 본인 소유 채팅방은 종료됩니다. '
              '정책에 정한 보존 항목은 해당 기간 보존되며, 탈퇴는 되돌릴 수 없습니다.',
              style: AppTextStyles.body7Gray,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
    if (yes != true || !_current) return;
    setState(() => _busy = true);
    try {
      await AuthApiService.instance.withdraw();
      if (mounted) context.go('/auth');
    } catch (_) {
      if (_current) {
        setState(() {
          _busy = false;
          _message = '탈퇴하지 못했어요. 계정은 유지됩니다. 다시 시도해주세요.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      // 이 화면으로 들어오는 링크가 '생년월일 정정 · 계정 탈퇴' 라 이름을 맞춘다.
      title: Text('생년월일 정정 · 계정 탈퇴', style: AppTextStyles.body4),
      leading: IconButton(
        onPressed: () => context.go('/service-consent'),
        // 앱의 다른 화면은 전부 쉐브론을 쓴다. 여기만 화살표였다.
        icon: AppIcon(SvgIcons.chevronLeft, size: 20),
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('이용 조건에 동의하지 않아도 내 정보를 정정하거나 탈퇴할 수 있습니다.'),
          const SizedBox(height: 16),
          Text(
            _birth == null
                ? '저장된 생년월일 없음'
                : '생년월일: ${_birth!.year}.${_birth!.month.toString().padLeft(2, '0')}.${_birth!.day.toString().padLeft(2, '0')}',
          ),
          const Text('이용 제한을 피하기 위한 허위 입력은 허용되지 않습니다.'),
          if (_busy) const Center(child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: AppLoadingIndicator(),
          )),
          if (_message != null) Text(_message!),
          TextButton(
            onPressed: _busy ? null : _correctBirth,
            child: const Text('잘못된 생년월일 정정'),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () {
                    setState(() => _busy = true);
                    _load();
                  },
            child: const Text('내 정보 다시 불러오기'),
          ),
          const SizedBox(height: 8),
          Divider(color: AppColors.neutralScale[100]),
          const SizedBox(height: 8),
          // 되돌릴 수 없는 동작이다. 위의 조회·정정과 같은 모양이면
          // 무엇이 위험한 버튼인지 화면에서 알 수 없다.
          TextButton.icon(
            onPressed: _busy ? null : _withdraw,
            icon: Icon(Icons.warning_amber_rounded,
                size: 18, color: AppColors.error),
            label: Text('계정 탈퇴',
                style: AppTextStyles.body4.copyWith(color: AppColors.error)),
          ),
          TextButton(
            onPressed: _busy ? null : () => context.go('/service-consent'),
            child: const Text('이용 조건 확인으로 돌아가기'),
          ),
        ],
      ),
    ),
  );
}
