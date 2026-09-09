import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../state/auth_store.dart';
import '../state/service_consent_store.dart';

/// 서버가 돌려준 오류.
///
/// 서버는 계층에 따라 두 가지 형태로 오류를 준다. 인증·채팅은 코드와 문구를
/// 담은 형태이고, 여행·리뷰·날씨는 다른 키를 쓴다. 어느 쪽이든 여기로 접는다.
class ApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;
  final bool retryable;

  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.retryable = false,
  });

  @override
  String toString() => '[$statusCode] $code: $message';
}

/// 토큰을 붙이고 만료를 처리하는 공통 HTTP 계층.
///
/// 401 을 만나면 한 번만 갱신하고 같은 요청을 다시 보낸다. 갱신 자체가
/// 실패하면 로그아웃 상태가 되고 401 을 그대로 올려보낸다.
///
/// **401 판정은 상태 코드로만 한다.** 보호된 자원의 401 은 본문이 비어 있어
/// 오류 코드로 가릴 수 없다.
///
/// **인증 경로는 갱신 대상이 아니다.** 로그인 실패나 갱신 실패도 401 로 오는데,
/// 그것을 만료로 오인해 다시 갱신하면 무한히 맴돈다.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  /// 따로 정하지 않은 요청이 기다리는 시간.
  ///
  /// 화면을 곧바로 채우는 조회는 이보다 짧게 잡는다. 부가 정보 하나가
  /// 이만큼 붙들면 사용자는 화면이 멈춘 것으로 본다 — 그런 요청은 호출하는
  /// 쪽에서 [timeout] 으로 자기 사정에 맞는 시간을 준다.
  static const _timeout = Duration(seconds: 30);

  /// 만료 갱신을 시도하지 않는 경로. 이 경로들의 401 은 만료가 아니라
  /// 자격 자체의 문제다.
  static bool _isAuthPath(String path) => path.startsWith('/api/v1/auth/');

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) => _send('GET', path, query: query, timeout: timeout);

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    Duration? timeout,
    bool Function()? canSend,
  }) => _send('POST', path, body: body, timeout: timeout, canSend: canSend);

  Future<Map<String, dynamic>> put(
    String path, {
    Object? body,
    Duration? timeout,
  }) => _send('PUT', path, body: body, timeout: timeout);

  Future<Map<String, dynamic>> patch(
    String path, {
    Object? body,
    Duration? timeout,
  }) => _send('PATCH', path, body: body, timeout: timeout);

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, String>? query,
    Object? body,
    Duration? timeout,
  }) => _send('DELETE', path, query: query, body: body, timeout: timeout);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    Duration? timeout,
    bool retried = false,
    bool Function()? canSend,
  }) async {
    _checkRequestPermission(canSend);
    if (!AppConfig.instance.requestsAllowed) {
      throw const ApiException(
        statusCode: 503,
        code: 'CONFIG_UNAVAILABLE',
        message: '서버 설정을 확인하지 못했어요. 잠시 후 앱을 다시 열어주세요.',
      );
    }
    final sessionVersion = AuthStore.instance.sessionVersion;
    if (AuthStore.instance.accessToken != null &&
        !ServiceConsentStore.permitsWithoutConsent(method, path) &&
        !ServiceConsentStore.instance.canAccess) {
      throw const ApiException(
        statusCode: 403,
        code: 'SERVICE_POLICY_REQUIRED',
        message: '만 18세 이상 및 이용약관·개인정보처리방침 확인이 필요해요.',
      );
    }
    final uri = Uri.parse(
      '$kApiBaseUrl$path',
    ).replace(queryParameters: query == null || query.isEmpty ? null : query);
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = AuthStore.instance.accessToken;
    if (token != null &&
        (!_isAuthPath(path) || path == '/api/v1/auth/logout')) {
      headers['Authorization'] = 'Bearer $token';
    }

    final http.Response response;
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) {
        request.body = jsonEncode(body);
      }
      _checkRequestPermission(canSend);
      response = await request
          .send()
          .then(http.Response.fromStream)
          .timeout(timeout ?? _timeout);
    } on TimeoutException {
      throw const ApiException(
        statusCode: 408,
        code: 'REQUEST_TIMEOUT',
        message: '응답이 지연되고 있어요. 잠시 후 다시 시도해주세요.',
      );
    } on http.ClientException {
      throw const ApiException(
        statusCode: 503,
        code: 'NETWORK_ERROR',
        message: '서버에 연결하지 못했어요. 인터넷 연결 상태를 확인해주세요.',
      );
    }

    if (sessionVersion != AuthStore.instance.sessionVersion) {
      throw const ApiException(
        statusCode: 409,
        code: 'SESSION_CHANGED',
        message: '로그인 상태가 변경됐어요. 다시 시도해주세요.',
      );
    }
    _checkRequestPermission(canSend);

    if (response.statusCode == 401 && !retried && !_isAuthPath(path)) {
      final refreshed = await AuthStore.instance.refresh();
      if (sessionVersion != AuthStore.instance.sessionVersion) {
        throw const ApiException(
          statusCode: 409,
          code: 'SESSION_CHANGED',
          message: '로그인 상태가 변경됐어요. 다시 시도해주세요.',
        );
      }
      if (refreshed) {
        return _send(
          method,
          path,
          query: query,
          body: body,
          timeout: timeout,
          retried: true,
          canSend: canSend,
        );
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Another concurrent response may have invalidated policy while this was in flight.
      if (token != null &&
          !ServiceConsentStore.permitsWithoutConsent(method, path) &&
          !ServiceConsentStore.instance.canAccess) {
        throw const ApiException(
          statusCode: 403,
          code: 'SERVICE_POLICY_REQUIRED',
          message: '이용 조건을 다시 확인해주세요.',
        );
      }
      if (response.body.isEmpty) {
        return const {};
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }

    final error = _toException(response);
    if (ServiceConsentStore.isPolicyDenial(error.statusCode, error.code)) {
      ServiceConsentStore.instance.invalidate(reason: error.code);
    }
    throw error;
  }

  static void _checkRequestPermission(bool Function()? canSend) {
    if (canSend != null && !canSend()) {
      throw const ApiException(
        statusCode: 403,
        code: 'REQUEST_PERMISSION_REVOKED',
        message: '요청 허용 상태가 바뀌어 전송과 응답 반영을 중단했어요.',
      );
    }
  }

  /// 목록을 돌려주는 경로용. 서버가 배열을 최상위로 주는 경우가 있다.
  Future<List<dynamic>> getList(
    String path, {
    Map<String, String>? query,
  }) async {
    final out = await _send('GET', path, query: query);
    final data = out['data'];
    return data is List ? data : const [];
  }

  ApiException _toException(http.Response response) {
    String code = 'UNKNOWN_ERROR';
    String message = '알 수 없는 오류가 발생했습니다.';
    bool retryable = false;
    if (response.body.isNotEmpty) {
      try {
        final parsed = jsonDecode(utf8.decode(response.bodyBytes));
        if (parsed is Map<String, dynamic>) {
          final errorCode = parsed['code'] ?? parsed['error'];
          final detail = parsed['message'] ?? parsed['detail'];
          if (errorCode is String) code = errorCode;
          if (detail is String) message = detail;
          final legacy = parsed['error'];
          if (legacy == 'trip_generation_failed' &&
              !_recommendationMessages.containsKey(code)) {
            code = 'generation_failed';
          } else if (code == 'trip_generation_timeout' ||
              (legacy == 'trip_generation_timeout' &&
                  !_recommendationMessages.containsKey(code))) {
            code = 'recommendation_pending';
          }
          if (_recommendationMessages.containsKey(code)) {
            // Only known transient terminal failures can recommend a new request.
            // A facade timeout can leave its worker running and is not retryable.
            retryable =
                parsed['retryable'] == true &&
                const {
                  'upstream_unavailable',
                  'generation_timeout',
                }.contains(code);
            message = code == 'upstream_unavailable' && retryable
                ? '추천에 필요한 정보를 가져오지 못했어요. 잠시 후 다시 시도해주세요.'
                : _recommendationMessages[code]!;
          }
        }
      } on FormatException {
        // 본문이 JSON 이 아니면 상태 코드만 남긴다.
      }
    }
    if (response.statusCode == 401) {
      message = '로그인이 필요해요.';
    }
    return ApiException(
      statusCode: response.statusCode,
      code: code,
      message: message,
      retryable: retryable,
    );
  }

  static const _recommendationMessages = {
    'no_matching_places': '현재 조건에서 추천할 장소를 찾지 못했어요. 선택 조건을 확인해주세요.',
    'selection_invalid': '추천 결과를 구성하지 못했어요. 선택한 장소와 일정을 확인해주세요.',
    'invalid_request': '선택한 장소와 일정 조건을 확인해주세요.',
    'upstream_unavailable': '추천에 필요한 정보를 가져오지 못했어요.',
    'quota_exceeded': '현재 추천 요청 한도에 도달했어요. 잠시 뒤 다시 확인해주세요.',
    'generation_timeout': '추천 생성 시간이 초과됐어요. 잠시 후 다시 시도해주세요.',
    'recommendation_pending': '추천 응답 대기 시간이 초과됐어요. 요청이 아직 처리 중일 수 있어요.',
    'generation_failed': '추천을 생성하지 못했어요.',
    'timeline_changed': '이동시간과 방문 가능 시간이 달라졌어요. 장소와 활동 시간을 확인해 동선을 다시 요청해주세요.',
  };
}
