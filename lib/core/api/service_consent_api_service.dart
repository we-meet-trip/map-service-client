import 'api_client.dart';
import '../state/service_consent_store.dart';

class ServiceConsentApiService {
  ServiceConsentApiService({ApiClient? api}) : _api = api ?? ApiClient.instance;
  static final instance = ServiceConsentApiService();
  final ApiClient _api;
  void bind(ServiceConsentStore store) {
    store.loadStatus = fetch;
    store.submitAcceptance = accept;
  }

  Future<ServiceConsentStatus> fetch() async =>
      ServiceConsentStatus.fromJson(await _api.get('/api/v1/consents'));
  Future<ServiceConsentStatus> accept(ServiceConsentStatus current) async =>
      ServiceConsentStatus.fromJson(
        await _api.post(
          '/api/v1/consents',
          body: {
            'terms_version': current.termsVersion,
            'privacy_version': current.privacyVersion,
            'is_18_or_older': true,
            'terms_accepted': true,
            'privacy_accepted': true,
          },
        ),
      );
}
