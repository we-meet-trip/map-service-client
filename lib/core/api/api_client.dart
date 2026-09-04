import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../state/auth_store.dart';

/// 서버가 돌려준 오류.
///
/// 서버는 계층에 따라 두 가지 형태로 오류를 준다. 인증·채팅은 코드와 문구를
/// 담은 형태이고, 여행·리뷰·날씨는 다른 키를 쓴다. 어느 쪽이든 여기로 접는다.
class ApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;

  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
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

  Future<Map<String, dynamic>> get(String path,
          {Map<String, String>? query, Duration? timeout}) =>
      _send('GET', path, query: query, timeout: timeout);

  Future<Map<String, dynamic>> post(String path,
          {Object? body, Duration? timeout}) =>
      _send('POST', path, body: body, timeout: timeout);

  Future<Map<String, dynamic>> put(String path,
          {Object? body, Duration? timeout}) =>
      _send('PUT', path, body: body, timeout: timeout);

  Future<Map<String, dynamic>> patch(String path,
          {Object? body, Duration? timeout}) =>
      _send('PATCH', path, body: body, timeout: timeout);

  Future<Map<String, dynamic>> delete(String path,
          {Object? body, Duration? timeout}) =>
      _send('DELETE', path, body: body, timeout: timeout);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    Duration? timeout,
    bool retried = false,
  }) async {
    final uri = Uri.parse('$kApiBaseUrl$path').replace(
      queryParameters: query == null || query.isEmpty ? null : query,
    );
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = AuthStore.instance.accessToken;
    if (token != null && !_isAuthPath(path)) {
      headers['Authorization'] = 'Bearer $token';
    }

    final http.Response response;
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) {
        request.body = jsonEncode(body);
      }
      final streamed = await request.send().timeout(timeout ?? _timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const ApiException(
        statusCode: 408,
        code: 'REQUEST_TIMEOUT',
        message: '응답이 지연되고 있어요. 잠시 후 다시 시도해주세요.',
      );
    }

    if (response.statusCode == 401 && !retried && !_isAuthPath(path)) {
      final refreshed = await AuthStore.instance.refresh();
      if (refreshed) {
        return _send(method, path,
            query: query, body: body, timeout: timeout, retried: true);
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return const {};
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    }

    throw _toException(response);
  }

  /// 목록을 돌려주는 경로용. 서버가 배열을 최상위로 주는 경우가 있다.
  Future<List<dynamic>> getList(String path,
      {Map<String, String>? query}) async {
    final out = await _send('GET', path, query: query);
    final data = out['data'];
    return data is List ? data : const [];
  }

  ApiException _toException(http.Response response) {
    String code = 'UNKNOWN_ERROR';
    String message = '알 수 없는 오류가 발생했습니다.';
    if (response.body.isNotEmpty) {
      try {
        final parsed = jsonDecode(utf8.decode(response.bodyBytes));
        if (parsed is Map<String, dynamic>) {
          code = parsed['code'] as String? ??
              parsed['error'] as String? ??
              code;
          message = parsed['message'] as String? ??
              parsed['detail'] as String? ??
              message;
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
    );
  }
}
