import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/auth_api_service.dart';
import '../../../core/api/service_consent_api_service.dart';
import '../../../core/api/user_api_service.dart';
import '../../../core/config/app_environment.dart';
import '../../../core/state/auth_store.dart';
import '../../../core/state/service_consent_store.dart';
import '../../../core/maps/map_bootstrap.dart';
import '../../moderation/moderation_center_screen.dart';

class ServiceConsentScreen extends StatefulWidget {
  const ServiceConsentScreen({
    super.key,
    this.store,
    this.onContinue,
    this.saveBirthDate,
  });
  final ServiceConsentStore? store;
  final VoidCallback? onContinue;
  final Future<void> Function(DateTime)? saveBirthDate;
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
  (String?, String?, int?, bool?)? _displayedPolicy;

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
      _adult = _terms = _privacy = false;
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
          'AGE_INFORMATION_REQUIRED' => '생년월일을 먼저 입력하고 이용 조건을 다시 확인해주세요.',
          'AGE_RESTRICTED' =>
            'MAP은 만 18세 이상만 이용할 수 있어요. 생년월일 정정 또는 탈퇴를 선택할 수 있습니다.',
          'POLICY_VERSION_MISMATCH' => '정책이 변경됐어요. 최신 내용을 다시 확인해주세요.',
          'COMMON_002' ||
          'VALIDATION_ERROR' ||
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

  Future<void> _enterBirthDate() async {
    if (_acting || !_current) return;
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1900),
      lastDate: now,
      initialDatePickerMode: DatePickerMode.year,
      helpText: '본인의 정확한 생년월일을 입력해주세요',
    );
    if (date == null || !_current) return;
    setState(() {
      _acting = true;
      _error = null;
      _adult = _terms = _privacy = false;
    });
    try {
      if (widget.saveBirthDate case final save?) {
        await save(date);
      } else {
        await UserApiService.instance.update(birthDate: date);
      }
      if (!_current) return;
      store.invalidate();
      await store.refresh(force: true);
      if (_current && store.status?.ageEligible == null) {
        setState(() => _error = '저장 결과를 확인하지 못했어요. 다시 확인해주세요.');
      }
    } catch (_) {
      if (_current) {
        setState(() => _error = '생년월일 저장 결과를 확인하지 못했어요. 다시 확인해주세요.');
      }
    } finally {
      if (_current) setState(() => _acting = false);
    }
  }

  Future<void> _openPolicy(String name) async {
    try {
      final status = store.status;
      final version = name == 'terms'
          ? status?.termsVersion
          : status?.privacyVersion;
      final opened = await launchUrl(
        AppEnvironment.policyUrl('$name.html').replace(
          queryParameters: version == null ? null : {'version': version},
        ),
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
      final currentPolicy = (
        status?.termsVersion,
        status?.privacyVersion,
        status?.minimumAge,
        status?.ageEligible,
      );
      if (_displayedPolicy != currentPolicy) {
        _displayedPolicy = currentPolicy;
        _adult = _terms = _privacy = false;
      }
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
                '약관과 개인정보 처리 내용을 확인하고 각각 동의해주세요. 내용이 변경되면 다시 확인해요. 외부 AI 전송 및 학습 데이터 제공 동의와는 별개입니다.',
              ),
              const SizedBox(height: 16),
              if (status != null && supported)
                Text(
                  '이용약관 ${status.termsVersion} · 개인정보처리방침 ${status.privacyVersion}',
                  style: const TextStyle(fontSize: 12),
                ),
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
                const Text(
                  '이 앱에서 확인할 수 없는 이용 조건이에요. 최신 앱으로 업데이트한 뒤 다시 확인해주세요.',
                ),
              if (blocked)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    '저장된 생년월일 기준 만 18세 미만으로 확인되어 이용할 수 없습니다. 생년월일이 잘못되었다면 정정하거나, 계정을 탈퇴할 수 있어요.',
                  ),
                ),
              if (status != null &&
                  supported &&
                  status.ageEligible == null) ...[
                const Text(
                  '먼저 생년월일을 입력해주세요. 만 18세 이상 여부를 서버에서 확인한 뒤 이용할 수 있습니다.',
                ),
                const Text('입력한 생년월일에 따른 연령 확인이며 본인인증을 뜻하지 않습니다.'),
                FilledButton(
                  key: const Key('policy-birth'),
                  onPressed: _acting ? null : _enterBirthDate,
                  child: const Text('생년월일 입력'),
                ),
              ],
              if (status != null &&
                  supported &&
                  status.ageEligible == true) ...[
                const Text(
                  '입력한 생년월일을 기준으로 서버에서 나이를 계산했습니다. 본인인증을 뜻하지 않습니다. AI 추천은 외부 AI 전송에 별도로 동의한 뒤 이용할 수 있습니다.',
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
