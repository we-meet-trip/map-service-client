import 'api_client.dart';
import '../../common/widgets/external_ai_consent.dart';

/// 화면에서 받은 외부 AI 전송 동의를 서버에도 남긴다.
///
/// 화면의 동의는 그 세션에만 있는 값이다. 서버는 추천을 돌릴 때마다 저장된
/// 동의를 다시 확인하므로, 남기지 않으면 사용자가 동의하고도 요청마다
/// 거절당한다.
///
/// 판과 개정 번호는 서버가 준 값을 그대로 되돌려 보낸다. 앱에 판을 박아 두면
/// 서버가 판을 올릴 때마다 앱을 다시 내야 동의가 통한다.
class AiConsentApiService {
  AiConsentApiService({ApiClient? api}) : _api = api ?? ApiClient.instance;
  static final instance = AiConsentApiService();
  final ApiClient _api;

  static const _names = {
    ExternalAiScope.trip: 'trip',
    ExternalAiScope.vision: 'vision',
    ExternalAiScope.reviewSummary: 'review_summary',
  };

  void bind(ExternalAiConsentGate gate) {
    gate.persistGrant = grant;
    gate.persistRevoke = revoke;
  }

  /// 지금 서버에 남아 있는 판과 개정 번호.
  Future<Map<String, dynamic>> _current(String scope) async {
    for (final row in await _api.getList('/api/v1/consents/ai')) {
      if (row is Map<String, dynamic> && row['scope'] == scope) return row;
    }
    throw ApiException(
      statusCode: 502,
      code: 'AI_CONSENT_STATUS_MISSING',
      message: '동의 상태를 확인하지 못했어요.',
    );
  }

  Future<void> grant(ExternalAiScope scope, bool includeLocation) async {
    final name = _names[scope]!;
    final now = await _current(name);
    await _api.post(
      '/api/v1/consents/ai/$name',
      body: {
        'policy_version': now['policy_version'],
        'accepted': true,
        'include_location': includeLocation,
        'expected_revision': now['revision'],
      },
    );
  }

  Future<void> revoke(ExternalAiScope scope) async {
    final name = _names[scope]!;
    final now = await _current(name);
    await _api.delete(
      '/api/v1/consents/ai/$name',
      query: {'expected_revision': '${now['revision']}'},
    );
  }
}
