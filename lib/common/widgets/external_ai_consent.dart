import 'package:flutter/material.dart';
import '../../core/state/auth_store.dart';

enum ExternalAiScope { vision, trip }

class ExternalAiPermission {
  ExternalAiPermission._(
    this.includeLocation,
    this._sessionVersion,
    this._currentSession,
  );
  final bool includeLocation;
  final int _sessionVersion;
  final int Function() _currentSession;
  bool get isCurrentSession => _sessionVersion == _currentSession();
}

/// Consent is separate for each use and never crosses an account session.
/// No consent is persisted, inferred from OS permission, or treated as learning consent.
class ExternalAiConsentGate {
  ExternalAiConsentGate({int Function()? sessionVersion})
    : _sessionVersion =
          sessionVersion ?? (() => AuthStore.instance.sessionVersion);
  final int Function() _sessionVersion;
  final Map<ExternalAiScope, ExternalAiPermission> _accepted = {};
  final Map<ExternalAiScope, Future<ExternalAiPermission?>> _pending = {};
  static final instance = ExternalAiConsentGate();

  Future<ExternalAiPermission?> ensure(
    BuildContext context,
    ExternalAiScope scope,
  ) async {
    final cached = _accepted[scope];
    if (cached?.isCurrentSession == true) return cached;
    if (_pending[scope] case final pending?) return pending;
    final work = _ask(context, scope);
    _pending[scope] = work;
    try {
      return await work;
    } finally {
      if (identical(_pending[scope], work)) _pending.remove(scope);
    }
  }

  Future<ExternalAiPermission?> _ask(
    BuildContext context,
    ExternalAiScope scope,
  ) async {
    final version = _sessionVersion();
    final selection = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ExternalAiConsentDialog(scope: scope),
    );
    if (selection == null || version != _sessionVersion()) return null;
    final permission = ExternalAiPermission._(
      selection,
      version,
      _sessionVersion,
    );
    _accepted[scope] = permission;
    return permission;
  }
}

Future<ExternalAiPermission?> ensureExternalAiConsent(
  BuildContext context,
  ExternalAiScope scope,
) => ExternalAiConsentGate.instance.ensure(context, scope);

class ExternalAiConsentDialog extends StatefulWidget {
  const ExternalAiConsentDialog({super.key, required this.scope});
  final ExternalAiScope scope;
  @override
  State<ExternalAiConsentDialog> createState() =>
      _ExternalAiConsentDialogState();
}

class _ExternalAiConsentDialogState extends State<ExternalAiConsentDialog> {
  bool _includeLocation = false;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.scope == ExternalAiScope.vision
          ? 'Vision 외부 AI 전송 동의'
          : '여행 추천 외부 AI 전송 동의',
    ),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.scope == ExternalAiScope.vision
                  ? 'MAP은 답변을 만들기 위해 촬영한 사진, 입력한 질문(음성을 글자로 바꾼 내용 포함), 최근 대화와 이전 인식 결과를 Google Gemini에 전달합니다.'
                  : 'MAP은 여행 추천과 설명을 만들기 위해 여행 지역·날짜·활동 시간, 이동수단, 예산·취향, 선택한 장소와 일정 정보를 Google Gemini에 전달합니다.',
            ),
            const SizedBox(height: 12),
            const Text(
              '전송에 동의해야 이 AI 기능을 사용할 수 있어요. 동의하지 않아도 다른 기능은 이용할 수 있습니다. '
              '사진과 질문에 불필요한 개인정보가 포함되지 않았는지 확인해주세요.',
            ),
            if (widget.scope == ExternalAiScope.vision)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('현재 위치도 답변에 사용 (선택)'),
                subtitle: const Text(
                  '허용하면 위치 주소 또는 약 100m 단위 좌표를 Google Gemini에 함께 전달합니다. 위치 없이도 질문할 수 있어요.',
                ),
                value: _includeLocation,
                onChanged: (value) =>
                    setState(() => _includeLocation = value ?? false),
              ),
            const SizedBox(height: 12),
            const Text('이 동의는 카메라·마이크·위치의 기기 권한 및 학습 데이터 제공 동의와 별개입니다.'),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('동의하지 않음'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_includeLocation),
        child: const Text('전송에 동의'),
      ),
    ],
  );
}
