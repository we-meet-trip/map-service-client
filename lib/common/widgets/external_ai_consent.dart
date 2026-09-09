import 'package:flutter/material.dart';
import '../../core/state/auth_store.dart';

enum ExternalAiScope { vision, trip, reviewSummary }

class ExternalAiPermission {
  ExternalAiPermission._(
    this.includeLocation,
    this._sessionVersion,
    this._currentSession,
    this._generation,
    this._currentGeneration,
  );
  final bool includeLocation;
  final int _sessionVersion;
  final int Function() _currentSession;
  final int _generation;
  final int Function() _currentGeneration;

  /// Existing callers use this guard before sending and applying a response.
  /// Revocation permanently invalidates this permission even after a new grant.
  bool get isCurrentSession =>
      _sessionVersion == _currentSession() &&
      _generation == _currentGeneration();
}

/// Consent is separate for each use and never crosses an account session.
/// No consent is persisted, inferred from OS permission, or treated as learning consent.
class ExternalAiConsentGate extends ChangeNotifier {
  ExternalAiConsentGate({int Function()? sessionVersion})
    : _sessionVersion =
          sessionVersion ?? (() => AuthStore.instance.sessionVersion);
  final int Function() _sessionVersion;
  final Map<ExternalAiScope, ExternalAiPermission> _accepted = {};
  final Map<ExternalAiScope, Future<ExternalAiPermission?>> _pending = {};
  final Map<ExternalAiScope, int> _generations = {};
  static final instance = ExternalAiConsentGate();

  /// 동의를 서버에 남기고 지우는 통로. 꽂지 않으면 이 화면 세션 안에서만
  /// 유효한 동의가 되고, 서버는 저장된 동의가 없다며 요청을 거절한다.
  Future<void> Function(ExternalAiScope scope, bool includeLocation)?
  persistGrant;
  Future<void> Function(ExternalAiScope scope)? persistRevoke;

  bool hasConsent(ExternalAiScope scope) =>
      _accepted[scope]?.isCurrentSession == true;

  bool includesLocation(ExternalAiScope scope) =>
      hasConsent(scope) && _accepted[scope]!.includeLocation;

  void revoke(ExternalAiScope scope) {
    _generations[scope] = (_generations[scope] ?? 0) + 1;
    _accepted.remove(scope);
    // 서버에서도 지운다. 실패해도 이 자리의 차단은 되돌리지 않는다 — 막는
    // 쪽으로 틀리는 것이 안전하고, 다음 이용 때 다시 물어본다.
    persistRevoke?.call(scope).catchError((Object _) {});
    // A dialog opened before revocation cannot restore its old permission.
    // Its pending result is rejected below; the next request asks again.
    notifyListeners();
  }

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
    final generation = _generations[scope] ?? 0;
    final selection = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ExternalAiConsentDialog(scope: scope),
    );
    if (selection == null ||
        version != _sessionVersion() ||
        generation != (_generations[scope] ?? 0)) {
      return null;
    }
    if (persistGrant case final persist?) {
      try {
        await persist(scope, selection);
      } catch (_) {
        // 서버에 남기지 못했으면 동의로 치지 않는다. 여기서 통과시키면
        // 사용자는 동의하고도 요청마다 거절당한다.
        return null;
      }
      // 서버를 다녀오는 사이에 계정이 바뀌거나 철회가 있었을 수 있다.
      if (version != _sessionVersion() ||
          generation != (_generations[scope] ?? 0)) {
        return null;
      }
    }
    final permission = ExternalAiPermission._(
      selection,
      version,
      _sessionVersion,
      generation,
      () => _generations[scope] ?? 0,
    );
    _accepted[scope] = permission;
    notifyListeners();
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
    title: Text(switch (widget.scope) {
      ExternalAiScope.vision => 'Vision 외부 AI 전송 동의',
      ExternalAiScope.trip => '여행 추천 외부 AI 전송 동의',
      ExternalAiScope.reviewSummary => '장소 리뷰 요약 외부 AI 전송 동의',
    }),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.scope == ExternalAiScope.reviewSummary
                  ? 'MAP은 선택한 장소명과 공개 블로그 후기 발췌문을 Google Gemini에 전달해 장소 리뷰를 요약합니다.'
                  : widget.scope == ExternalAiScope.vision
                  ? 'MAP은 답변을 만들기 위해 촬영한 사진, 입력한 질문(음성을 글자로 바꾼 내용 포함), 최근 대화와 이전 인식 결과를 Google Gemini에 전달합니다.'
                  : 'MAP은 여행 추천과 설명을 만들기 위해 여행 지역·날짜·활동 시간, 이동수단, 예산·취향, 선택한 장소와 일정 정보를 Google Gemini에 전달합니다.',
            ),
            const SizedBox(height: 12),
            const Text(
              '전송에 동의해야 이 AI 기능을 사용할 수 있어요. 동의하지 않아도 다른 기능은 이용할 수 있습니다.',
            ),
            if (widget.scope == ExternalAiScope.vision)
              const Text('사진과 질문에 불필요한 개인정보가 포함되지 않았는지 확인해주세요.'),
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
            const SizedBox(height: 12),
            const Text('마이페이지 → 외부 AI 전송 동의 설정에서 언제든 철회할 수 있어요.'),
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
