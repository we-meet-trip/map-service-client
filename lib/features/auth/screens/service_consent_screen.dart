import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/auth_api_service.dart';
import '../../../core/api/service_consent_api_service.dart';
import '../../../core/state/auth_store.dart';
import '../../../core/state/service_consent_store.dart';
import '../../../core/maps/map_bootstrap.dart';
import '../../moderation/moderation_center_screen.dart';

class ServiceConsentScreen extends StatefulWidget {
  const ServiceConsentScreen({super.key, this.store, this.onContinue});
  final ServiceConsentStore? store;
  final VoidCallback? onContinue;
  @override
  State<ServiceConsentScreen> createState() => _ServiceConsentScreenState();
}

class _ServiceConsentScreenState extends State<ServiceConsentScreen> {
  late final store = widget.store ?? ServiceConsentStore.instance;
  final _session = AuthStore.instance.sessionVersion;
  bool _adult = false;
  bool _terms = false;
  bool _privacy = false;
  bool _acting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.store == null) ServiceConsentApiService.instance.bind(store);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  bool get _current => mounted && _session == AuthStore.instance.sessionVersion;
  Future<void> _load() async {
    if (_acting) return;
    setState(() {
      _acting = true;
      _error = null;
    });
    try {
      await store.refresh(force: store.error != null);
      if (_current && store.canAccess) await _continue();
    } catch (_) {
      if (_current) {
        setState(() => _error = '이용 조건을 확인하지 못했어요. 연결을 확인하고 다시 시도해주세요.');
      }
    } finally {
      if (_current) setState(() => _acting = false);
    }
  }

  Future<void> _continue() async {
    if (!_current || !store.canAccess) return;
    if (widget.onContinue case final callback?) {
      callback();
      return;
    }
    if (!mapsReady.value) await initializeMaps();
    if (!mounted || !_current || !store.canAccess) return;
    final destination = store.takeDestination();
    context.go(destination.location, extra: destination.extra);
  }

  Future<void> _accept() async {
    if (_acting || !_adult || !_terms || !_privacy || !_current) return;
    setState(() {
      _acting = true;
      _error = null;
    });
    try {
      await store.accept(adult: _adult, terms: _terms, privacy: _privacy);
      if (!_current) return;
      if (store.canAccess) {
        await _continue();
      } else {
        setState(() => _error = '이용 동의가 확인되지 않았어요. 다시 확인해주세요.');
      }
    } on ApiException catch (e) {
      if (!_current) return;
      setState(() {
        _error = switch (e.code) {
          'AGE_RESTRICTED' =>
            'MAP은 만 18세 이상만 이용할 수 있어요. 생년월일 정정 또는 탈퇴를 선택할 수 있습니다.',
          'POLICY_VERSION_MISMATCH' => '정책이 변경됐어요. 최신 내용을 다시 확인해주세요.',
          'COMMON_002' ||
          'VALIDATION_FAILED' ||
          'POLICY_ACCEPTANCE_INVALID' => '만 18세 이상 확인과 두 정책 동의를 각각 선택해주세요.',
          _ => '동의를 저장하지 못했어요. 다시 시도해주세요.',
        };
        _adult = _terms = _privacy = false;
      });
    } catch (_) {
      if (_current) setState(() => _error = '동의를 저장하지 못했어요. 다시 시도해주세요.');
    } finally {
      if (_current) setState(() => _acting = false);
    }
  }

  Future<void> _openPolicy(String name) async {
    try {
      final opened = await launchUrl(
        Uri.parse('https://mapcenter-b59ca.web.app/legal/$name.html'),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw StateError('Unavailable');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('정책 문서를 열지 못했어요. 연결을 확인하고 다시 시도해주세요.')),
        );
      }
    }
  }

  Future<void> _logout() async {
    if (_acting) return;
    setState(() => _acting = true);
    await AuthApiService.instance.logout();
    if (mounted) context.go('/auth');
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final status = store.status;
      final blocked = status?.ageEligible == false;
      final supported = status?.supported == true;
      return Scaffold(
        appBar: AppBar(
          title: const Text('MAP 이용 조건 확인'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'MAP은 만 18세 이상을 위한 서비스입니다.',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                '약관과 개인정보 처리 내용을 확인하고 각각 동의해주세요. 기존 회원도 처음 한 번 확인해야 합니다. 외부 AI 전송 및 학습 데이터 제공 동의와는 별개입니다.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => _openPolicy('terms'),
                    child: const Text('이용약관 읽기'),
                  ),
                  TextButton(
                    onPressed: () => _openPolicy('privacy'),
                    child: const Text('개인정보처리방침 읽기'),
                  ),
                ],
              ),
              if (_acting || store.loading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (status == null && !_acting) ...[
                const Text('서버에서 이용 조건을 확인한 뒤 계속할 수 있어요.'),
                FilledButton(onPressed: _load, child: const Text('다시 확인')),
              ],
              if (status != null && !supported)
                const Text('정책 버전이 변경됐어요. 최신 앱으로 업데이트한 뒤 내용을 확인해주세요.'),
              if (blocked)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    '저장된 생년월일 기준 만 18세 미만으로 확인되어 이용할 수 없습니다. 생년월일이 잘못되었다면 정정하거나, 계정을 탈퇴할 수 있어요.',
                  ),
                ),
              if (status != null && supported && !blocked) ...[
                Text(
                  status.ageEligible == null
                      ? '생년월일을 저장하지 않은 계정입니다. 아래 만 18세 이상 확인은 본인의 진술이며 성인 인증을 뜻하지 않습니다.'
                      : '저장된 생년월일을 기준으로 나이를 계산했습니다. 별도의 성인 인증을 뜻하지 않습니다.',
                ),
                CheckboxListTile(
                  key: const Key('policy-adult'),
                  value: _adult,
                  onChanged: _acting
                      ? null
                      : (v) => setState(() => _adult = v == true),
                  title: const Text('만 18세 이상입니다 (필수)'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  key: const Key('policy-terms'),
                  value: _terms,
                  onChanged: _acting
                      ? null
                      : (v) => setState(() => _terms = v == true),
                  title: Text('이용약관에 동의합니다 (필수 · ${status.termsVersion})'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  key: const Key('policy-privacy'),
                  value: _privacy,
                  onChanged: _acting
                      ? null
                      : (v) => setState(() => _privacy = v == true),
                  title: Text(
                    '개인정보처리방침을 확인하고 동의합니다 (필수 · ${status.privacyVersion})',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                FilledButton(
                  onPressed: !_acting && _adult && _terms && _privacy
                      ? _accept
                      : null,
                  child: const Text('동의하고 계속'),
                ),
              ],
              const Divider(height: 32),
              TextButton(
                onPressed: _acting
                    ? null
                    : () => context.go('/service-consent/profile'),
                child: const Text('생년월일 정정 · 계정 탈퇴'),
              ),
              TextButton(
                onPressed: _acting ? null : () => openModerationCenter(context),
                child: const Text('신고 처리 상태 · 차단 관리'),
              ),
              TextButton(
                onPressed: _acting ? null : _logout,
                child: const Text('로그아웃'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
