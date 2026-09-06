import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../state/auth_store.dart';
import 'api_client.dart';
import 'auth_api_service.dart';

/// 요청의 state와 시작한 세션을 확인한 뒤 외부 브라우저의 인가 코드를 교환한다.
class KakaoLoginFlow {
  KakaoLoginFlow({
    Future<String> Function(String)? authorizeUrl,
    Future<bool> Function(Uri)? launch,
    Stream<Uri> Function()? callbacks,
    Future<void> Function(String)? exchange,
    int Function()? sessionVersion,
    String Function()? storageScope,
    Timer Function(Duration, void Function())? callbackTimer,
    Duration timeout = const Duration(minutes: 3),
  }) : _authorizeUrl =
           authorizeUrl ?? AuthApiService.instance.kakaoAuthorizeUrl,
       _launch =
           launch ??
           ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication)),
       _callbacks = callbacks ?? (() => AppLinks().uriLinkStream),
       _exchange = exchange ?? AuthApiService.instance.kakaoLogin,
       _sessionVersion =
           sessionVersion ?? (() => AuthStore.instance.sessionVersion),
       _storageScope = storageScope ?? (() => AppConfig.instance.storageScope),
       _callbackTimer = callbackTimer ?? Timer.new,
       _timeout = timeout;

  static final KakaoLoginFlow instance = KakaoLoginFlow();

  final Future<String> Function(String) _authorizeUrl;
  final Future<bool> Function(Uri) _launch;
  final Stream<Uri> Function() _callbacks;
  final Future<void> Function(String) _exchange;
  final int Function() _sessionVersion;
  final String Function() _storageScope;
  final Timer Function(Duration, void Function()) _callbackTimer;
  final Duration _timeout;
  bool _running = false;

  static const _timedOut = ApiException(
    statusCode: 0,
    code: 'KAKAO_TIMEOUT',
    message: '로그인이 완료되지 않았어요. 다시 시도해주세요.',
  );

  Future<void> run(String state) async {
    if (_running) {
      throw const ApiException(
        statusCode: 409,
        code: 'KAKAO_IN_PROGRESS',
        message: '진행 중인 로그인을 먼저 완료해주세요.',
      );
    }
    if (state.trim().isEmpty) {
      throw const ApiException(
        statusCode: 400,
        code: 'KAKAO_INVALID_STATE',
        message: '로그인을 다시 시도해주세요.',
      );
    }
    _running = true;
    final version = _sessionVersion();
    final scope = _storageScope();
    StreamSubscription<Uri>? subscription;
    Timer? timer;

    void checkSession() {
      if (version != _sessionVersion() || scope != _storageScope()) {
        throw const ApiException(
          statusCode: 409,
          code: 'SESSION_CHANGED',
          message: '로그인 상태가 변경됐어요. 다시 시도해주세요.',
        );
      }
    }

    try {
      final url = await _authorizeUrl(state);
      checkSession();
      // 브라우저가 즉시 돌아와도 놓치지 않도록 먼저 구독한다. 결과 자체에는
      // 오류를 값으로 보관하여 launch 실패 중의 콜백 오류도 미처리 Future가 되지 않는다.
      final returned = Completer<_CallbackResult>();
      void finish(_CallbackResult result) {
        if (!returned.isCompleted) returned.complete(result);
      }

      subscription = _callbacks().listen(
        (uri) {
          if (uri.scheme != 'mapauth' ||
              uri.host != 'kakao' ||
              (uri.path.isNotEmpty && uri.path != '/') ||
              uri.queryParameters['state'] != state) {
            return;
          }
          final error = uri.queryParameters['error'];
          if (error != null && error.isNotEmpty) {
            finish(
              const _CallbackResult.failure(
                ApiException(
                  statusCode: 0,
                  code: 'KAKAO_CANCELLED',
                  message: '카카오 로그인이 취소되었어요.',
                ),
              ),
            );
            return;
          }
          final code = uri.queryParameters['code'];
          finish(
            code == null || code.isEmpty
                ? const _CallbackResult.failure(
                    ApiException(
                      statusCode: 0,
                      code: 'KAKAO_NO_CODE',
                      message: '카카오에서 인가 정보를 받지 못했어요.',
                    ),
                  )
                : _CallbackResult.success(code),
          );
        },
        onError: (Object _, StackTrace _) {
          finish(
            const _CallbackResult.failure(
              ApiException(
                statusCode: 0,
                code: 'KAKAO_CALLBACK_UNAVAILABLE',
                message: '로그인 정보를 받지 못했어요. 다시 시도해주세요.',
              ),
            ),
          );
        },
        onDone: () {
          finish(
            const _CallbackResult.failure(
              ApiException(
                statusCode: 0,
                code: 'KAKAO_CALLBACK_UNAVAILABLE',
                message: '로그인 정보를 받지 못했어요. 다시 시도해주세요.',
              ),
            ),
          );
        },
      );
      timer = _callbackTimer(_timeout, () {
        finish(const _CallbackResult.failure(_timedOut));
      });

      final bool opened;
      try {
        opened = await _launch(Uri.parse(url)).timeout(_timeout);
      } on TimeoutException {
        throw _timedOut;
      } catch (_) {
        throw const ApiException(
          statusCode: 0,
          code: 'BROWSER_UNAVAILABLE',
          message: '브라우저를 열지 못했어요.',
        );
      }
      if (!opened) {
        throw const ApiException(
          statusCode: 0,
          code: 'BROWSER_UNAVAILABLE',
          message: '브라우저를 열지 못했어요.',
        );
      }

      final result = await returned.future;
      checkSession();
      if (result.error != null) throw result.error!;
      // 교환 중 다른 계정으로 바뀐 경우는 ApiClient의 응답 epoch 검사도 막는다.
      await _exchange(result.code!);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        statusCode: 0,
        code: 'KAKAO_UNAVAILABLE',
        message: '카카오 로그인에 연결하지 못했어요. 다시 시도해주세요.',
      );
    } finally {
      timer?.cancel();
      try {
        await subscription?.cancel();
      } finally {
        _running = false;
      }
    }
  }
}

class _CallbackResult {
  const _CallbackResult.success(this.code) : error = null;
  const _CallbackResult.failure(this.error) : code = null;

  final String? code;
  final ApiException? error;
}
