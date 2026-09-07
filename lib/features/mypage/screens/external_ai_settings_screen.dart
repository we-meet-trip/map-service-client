import 'package:flutter/material.dart';
import '../../../common/widgets/external_ai_consent.dart';
import '../../../core/state/auth_store.dart';

class ExternalAiSettingsScreen extends StatelessWidget {
  const ExternalAiSettingsScreen({super.key, this.consentGate});
  final ExternalAiConsentGate? consentGate;

  @override
  Widget build(BuildContext context) {
    final gate = consentGate ?? ExternalAiConsentGate.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('외부 AI 전송 동의 설정')),
      body: AnimatedBuilder(
        animation: Listenable.merge([gate, AuthStore.instance.sessionChanges]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Google Gemini 전송 동의는 기능별로 관리합니다. 동의는 이번 로그인에서만 유효하며, '
              '철회해도 서비스 이용약관 동의나 계정은 바뀌지 않습니다.',
            ),
            const SizedBox(height: 16),
            for (final scope in ExternalAiScope.values)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(switch (scope) {
                        ExternalAiScope.vision => 'Vision 질문',
                        ExternalAiScope.trip => '여행 추천·재탐색',
                        ExternalAiScope.reviewSummary => '장소 리뷰 요약',
                      }, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(gate.hasConsent(scope) ? '동의함 · 이번 로그인' : '동의하지 않음'),
                      if (scope == ExternalAiScope.vision &&
                          gate.hasConsent(scope))
                        Text(
                          gate.includesLocation(scope)
                              ? '현재 위치도 함께 전송하도록 동의함'
                              : '현재 위치 전송에 동의하지 않음',
                        ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        key: ValueKey('revoke-${scope.name}'),
                        onPressed: gate.hasConsent(scope)
                            ? () => _revoke(context, gate, scope)
                            : null,
                        child: const Text('동의 철회'),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              '철회하면 이 앱에서 해당 기능의 새 AI 전송을 중지하고, 진행 중인 응답을 표시하지 않습니다. '
              '다시 이용할 때 전송 내용을 확인하고 새로 동의할 수 있어요.',
            ),
            const SizedBox(height: 12),
            const Text(
              '이미 서버나 외부 AI로 보낸 정보를 삭제하거나 해당 요청의 처리를 취소하는 기능은 아닙니다. '
              '카메라·마이크·위치의 기기 권한과 학습 데이터 제공 동의도 변경하지 않습니다.',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _revoke(
    BuildContext context,
    ExternalAiConsentGate gate,
    ExternalAiScope scope,
  ) async {
    final session = AuthStore.instance.sessionVersion;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('외부 AI 전송 동의를 철회할까요?'),
        content: const Text(
          '앞으로 이 기능에서 새로 전송하지 않으며, 진행 중인 응답도 표시하지 않습니다. 이미 전송된 정보의 삭제를 뜻하지는 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('철회하기'),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !context.mounted ||
        session != AuthStore.instance.sessionVersion) {
      return;
    }
    gate.revoke(scope);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('동의를 철회했어요. 다음 이용 시 다시 동의할 수 있습니다.')),
    );
  }
}
