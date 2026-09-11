import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
      builder: (context) => AlertDialog(
        title: const Text('계정을 탈퇴할까요?'),
        content: const Text(
          '계정·프로필·본인 일정과 추천 결과·본인이 작성한 채팅 내용이 삭제됩니다. 다른 참여자가 작성한 메시지는 보존되고, 본인 소유 채팅방은 종료됩니다. 정책에 정한 보존 항목은 해당 기간 보존되며, 탈퇴는 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('탈퇴하기'),
          ),
        ],
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
      title: const Text('계정 정정 · 탈퇴'),
      leading: IconButton(
        onPressed: () => context.go('/service-consent'),
        icon: const Icon(Icons.arrow_back),
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
          if (_busy) const Center(child: CircularProgressIndicator()),
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
            child: const Text('서버 정보 다시 조회'),
          ),
          const Divider(),
          TextButton(
            onPressed: _busy ? null : _withdraw,
            child: const Text('계정 탈퇴'),
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
