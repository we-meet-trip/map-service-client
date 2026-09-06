import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/api/apple_login_flow.dart';
import 'package:map_service_client/core/api/api_client.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

void main() {
  AuthorizationCredentialAppleID credential(String? state) =>
      AuthorizationCredentialAppleID(
        authorizationCode: 'code',
        identityToken: 'identity',
        state: state,
        userIdentifier: 'apple-subject',
        givenName: '여행자',
        familyName: null,
        email: null,
      );

  test('server challenge binds native credentials and code exchange', () async {
    Map<String, dynamic>? sent;
    final flow = AppleLoginFlow(
      challenge: () async => {'nonce': 'nonce', 'state': 'state'},
      authorize: (nonce, state) async {
        expect(nonce, 'nonce');
        expect(state, 'state');
        return credential(state);
      },
      exchange: (body) async {
        sent = body;
      },
    );
    expect(await flow.run(), isTrue);
    expect(sent, {
      'identityToken': 'identity',
      'authorizationCode': 'code',
      'state': 'state',
      'nickname': '여행자',
    });
  });

  test('mismatched callback state never creates an app session', () async {
    final flow = AppleLoginFlow(
      challenge: () async => {'nonce': 'nonce', 'state': 'state'},
      authorize: (_, state) async => credential('other'),
      exchange: (_) async => fail('must not exchange invalid state'),
    );
    await expectLater(
      flow.run(),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );
  });

  test(
    'disabled server configuration does not open native authorization',
    () async {
      final flow = AppleLoginFlow(
        challenge: () async => throw const ApiException(
          statusCode: 503,
          code: 'UNAVAILABLE',
          message: 'unavailable',
        ),
        authorize: (_, state) async =>
            throw StateError('must not open Apple UI'),
        exchange: (_) async => fail('must not create session'),
      );
      await expectLater(
        flow.run(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 503)),
      );
    },
  );

  test('cancellation leaves the account unchanged', () async {
    final flow = AppleLoginFlow(
      challenge: () async => {'nonce': 'nonce', 'state': 'state'},
      authorize: (_, state) async =>
          throw const SignInWithAppleAuthorizationException(
            code: AuthorizationErrorCode.canceled,
            message: 'canceled',
          ),
      exchange: (_) async => fail('must not create session'),
    );
    expect(await flow.run(), isFalse);
  });
}
