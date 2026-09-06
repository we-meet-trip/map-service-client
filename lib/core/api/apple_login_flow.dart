import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../state/auth_store.dart';
import 'api_client.dart';
import 'auth_api_service.dart';

/// 서버의 일회용 challenge와 Apple native 자격을 짝지어 검증한다.
class AppleLoginFlow {
  AppleLoginFlow({
    Future<Map<String, dynamic>> Function()? challenge,
    Future<AuthorizationCredentialAppleID> Function(String, String)? authorize,
    Future<void> Function(Map<String, dynamic>)? exchange,
  }) : _challenge = challenge ?? AuthApiService.instance.appleNonce,
       _authorize =
           authorize ??
           ((nonce, state) => SignInWithApple.getAppleIDCredential(
             scopes: [
               AppleIDAuthorizationScopes.email,
               AppleIDAuthorizationScopes.fullName,
             ],
             nonce: nonce,
             state: state,
           )),
       _exchange = exchange ?? AuthApiService.instance.appleLogin;

  final Future<Map<String, dynamic>> Function() _challenge;
  final Future<AuthorizationCredentialAppleID> Function(String, String)
  _authorize;
  final Future<void> Function(Map<String, dynamic>) _exchange;

  Future<bool> run() async {
    final version = AuthStore.instance.sessionVersion;
    try {
      final challenge = await _challenge();
      final nonce = challenge['nonce'];
      final state = challenge['state'];
      if (nonce is! String ||
          nonce.isEmpty ||
          state is! String ||
          state.isEmpty) {
        throw const ApiException(
          statusCode: 503,
          code: 'APPLE_UNAVAILABLE',
          message: 'Apple 로그인 설정을 확인하지 못했어요.',
        );
      }
      final credential = await _authorize(nonce, state);
      if (credential.state != state ||
          credential.identityToken == null ||
          credential.identityToken!.isEmpty ||
          credential.authorizationCode.isEmpty) {
        throw const ApiException(
          statusCode: 401,
          code: 'APPLE_INVALID_RESPONSE',
          message: 'Apple 로그인 정보를 확인하지 못했어요. 다시 시도해주세요.',
        );
      }
      if (version != AuthStore.instance.sessionVersion) {
        throw const ApiException(
          statusCode: 409,
          code: 'SESSION_CHANGED',
          message: '로그인 상태가 변경됐어요.',
        );
      }
      final nickname = [
        credential.familyName,
        credential.givenName,
      ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ').trim();
      await _exchange({
        'identityToken': credential.identityToken,
        'authorizationCode': credential.authorizationCode,
        'state': state,
        if (nickname.isNotEmpty) 'nickname': nickname,
      });
      return true;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return false;
      throw const ApiException(
        statusCode: 0,
        code: 'APPLE_AUTH_FAILED',
        message: 'Apple 로그인을 완료하지 못했어요. 다시 시도해주세요.',
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        statusCode: 0,
        code: 'APPLE_UNAVAILABLE',
        message: 'Apple 로그인에 연결하지 못했어요. 잠시 후 다시 시도해주세요.',
      );
    }
  }
}
