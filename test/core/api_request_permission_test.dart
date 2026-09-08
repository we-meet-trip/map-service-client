import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:map_service_client/core/api/api_client.dart';
import 'package:map_service_client/core/state/auth_store.dart';
import 'package:map_service_client/core/state/service_consent_store.dart';

class _RevokingPayload {
  _RevokingPayload(this.revoke);
  final void Function() revoke;
  Map<String, Object> toJson() {
    revoke();
    return {'fixture': true};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final auth = AuthStore.instance;
  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
    await auth.save(
      const AuthTokens(
        accessToken: 'synthetic-a',
        refreshToken: 'synthetic-r',
        userId: 1,
      ),
    );
    final consent = ServiceConsentStore.instance;
    consent.loadStatus = () async => ServiceConsentStatus.fromJson({
      'terms_version': servicePolicyVersion,
      'privacy_version': servicePrivacyVersion,
      'minimum_age': 18,
      'accepted': true,
      'age_eligible': true,
      'accepted_at': '2026-09-07T00:00:00Z',
    });
    await consent.refresh(force: true);
  });
  tearDown(() {
    auth.refreshHandler = null;
  });
  final denied = throwsA(
    isA<ApiException>().having(
      (e) => e.code,
      'code',
      'REQUEST_PERMISSION_REVOKED',
    ),
  );

  test(
    'permission is checked after encoding and immediately before sending',
    () async {
      var allowed = true;
      var calls = 0;
      await http.runWithClient(
        () async {
          await expectLater(
            ApiClient.instance.post(
              '/api/v1/reviews/summary',
              body: _RevokingPayload(() => allowed = false),
              canSend: () => allowed,
            ),
            denied,
          );
        },
        () => MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      expect(calls, 0);
    },
  );

  test('withdrawn request opens no HTTP connection', () async {
    var calls = 0;
    await http.runWithClient(
      () async {
        await expectLater(
          ApiClient.instance.post(
            '/api/v1/trip/generate',
            canSend: () => false,
          ),
          denied,
        );
      },
      () => MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    expect(calls, 0);
  });

  test(
    'revocation during token refresh prevents retransmission of request body',
    () async {
      var generation = 0;
      var calls = 0;
      final refreshStarted = Completer<void>();
      final refreshed = Completer<AuthTokens?>();
      auth.refreshHandler = (_) {
        refreshStarted.complete();
        return refreshed.future;
      };
      await http.runWithClient(
        () async {
          final result = ApiClient.instance.post(
            '/api/v1/trip/generate',
            body: {'synthetic': 'private request'},
            canSend: () => generation == 0,
          );
          final checked = expectLater(result, denied);
          await refreshStarted.future;
          generation++;
          refreshed.complete(
            const AuthTokens(
              accessToken: 'synthetic-new',
              refreshToken: 'synthetic-new-r',
              userId: 1,
            ),
          );
          await checked;
        },
        () => MockClient((_) async {
          calls++;
          return http.Response('', 401);
        }),
      );
      expect(calls, 1);
      expect(ServiceConsentStore.instance.canAccess, isTrue);
      expect(auth.isLoggedIn.value, isTrue);
    },
  );

  test(
    'unchanged permission permits the single existing authentication retry',
    () async {
      var calls = 0;
      auth.refreshHandler = (_) async => const AuthTokens(
        accessToken: 'synthetic-new',
        refreshToken: 'synthetic-new-r',
        userId: 1,
      );
      await http.runWithClient(
        () async {
          expect(
            await ApiClient.instance.post(
              '/api/v1/trip/research',
              canSend: () => true,
            ),
            {'ok': true},
          );
        },
        () => MockClient(
          (_) async => ++calls == 1
              ? http.Response('', 401)
              : http.Response('{"ok":true}', 200),
        ),
      );
      expect(calls, 2);
    },
  );

  test(
    'permission withdrawn after send prevents applying the eventual response',
    () async {
      var allowed = true;
      final response = Completer<http.Response>();
      await http.runWithClient(() async {
        final result = ApiClient.instance.post(
          '/api/v1/trip/generate',
          canSend: () => allowed,
        );
        final checked = expectLater(result, denied);
        allowed = false;
        response.complete(
          http.Response('{"sensitive_result":"synthetic"}', 200),
        );
        await checked;
      }, () => MockClient((_) => response.future));
    },
  );
}
