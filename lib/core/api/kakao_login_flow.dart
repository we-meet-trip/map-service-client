import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../config/app_environment.dart';
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
  void Function(_CallbackResult)? _pending;

  static const _timedOut = ApiException(
    statusCode: 0,
    code: 'KAKAO_TIMEOUT',
    message: '로그인이 완료되지 않았어요. 다시 시도해주세요.',
  );

  static const _cancelled = ApiException(
    statusCode: 0,
    code: 'KAKAO_CANCELLED',
    message: '카카오 로그인이 취소되었어요.',
  );

  /// 기다리는 중인 로그인을 끝낸다. 기다리는 것이 없으면 아무 일도 하지 않는다.
  ///
  /// 외부 브라우저가 되돌려 주지 않으면 이 흐름은 제한 시간까지 기다리고, 그
  /// 사이 화면의 로그인 선택이 잠긴다. 사용자가 브라우저에서 그냥 돌아온 경우와
  /// 취소를 누른 경우에 호출한다. 이미 끝난 로그인에는 영향이 없다.
  bool cancel() {
    final pending = _pending;
    if (pending == null) return false;
    pending(const _CallbackResult.failure(_cancelled));
    return true;
  }

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

      _pending = finish;

      subscription = _callbacks().listen(
        (uri) {
          if (uri.scheme != AppEnvironment.kakaoScheme ||
              uri.host != 'kakao' ||
              uri.userInfo.isNotEmpty ||
              uri.hasPort ||
              uri.hasFragment ||
              (uri.path.isNotEmpty && uri.path != '/') ||
              uri.queryParametersAll['state']?.length != 1 ||
              (uri.queryParametersAll['code']?.length ?? 0) > 1 ||
              (uri.queryParametersAll['error']?.length ?? 0) > 1 ||
              uri.queryParameters['state'] != state) {
            return;
          }
          final error = uri.queryParameters['error'];
          if (error != null && error.isNotEmpty) {
            finish(const _CallbackResult.failure(_cancelled));
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
      _pending = null;
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
