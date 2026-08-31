import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// 앱이 어느 서버를 볼지 정하는 곳.
///
/// 서버 주소를 빌드에 굽지 않는다. 설치본은 하나인데 서버 주소는 자주 바뀌기
/// 때문이다. 대신 시작할 때 고정된 위치에서 현재 주소를 읽어 온다. 주소가
/// 바뀌면 그 파일만 갈아 끼우면 되고, 앱을 다시 만들거나 다시 깔 필요가 없다.
///
/// 정하는 순서:
///   1. 빌드 때 `--dart-define=API_BASE_URL` 로 넘어온 값 — 개발용 고정 주소다.
///      이 값이 있으면 원격 조회 자체를 하지 않는다. 개발 중에 원격 값이
///      끼어들면 방금 띄운 로컬 서버 대신 엉뚱한 곳을 보게 된다.
///   2. 원격 설정 파일의 값.
///   3. 마지막으로 성공했던 값(기기에 남겨 둔다) — 원격을 못 읽는 상황,
///      이를테면 비행기 모드에서 켰을 때 쓴다.
///   4. 로컬 기본값.
///
/// 원격 조회는 짧은 상한을 둔다. 첫 화면이 뜨기 전에 하는 일이라, 여기서
/// 오래 기다리면 앱이 멈춘 것처럼 보인다. 못 읽으면 곧바로 3번으로 내려간다.
class AppConfig {
  AppConfig._();

  static final AppConfig instance = AppConfig._();

  /// 빌드 때 주소를 넘겼는지. 넘겼다면 그 값이 무조건 이긴다.
  static const bool _hasInjectedBaseUrl = bool.hasEnvironment('API_BASE_URL');
  static const String _injectedBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// 현재 주소를 적어 두는 곳. 값 자체가 아니라 위치가 고정이다.
  static const String _remoteConfigUrl = String.fromEnvironment(
    'APP_CONFIG_URL',
    defaultValue: 'https://mapcenter-b59ca.web.app/app_config.json',
  );

  static const String _fallbackBaseUrl = 'http://localhost:8080';

  /// 첫 화면 직전에 하는 일이라 짧게 끊는다.
  static const Duration _remoteTimeout = Duration(seconds: 3);

  /// 첫 조회가 실패했을 때 뒤에서 다시 물어보는 간격.
  ///
  /// 첫 조회는 화면을 막지 않으려고 짧게 끊는데, 그 짧은 창에 걸리는 상황이
  /// 실제로 있다. 막 설치한 기기를 느린 망에서 처음 켜면 이름 조회와 연결
  /// 수립만으로 상한을 넘긴다. 그때 한 번으로 끝내면 캐시도 없어 로컬 기본값에
  /// 갇히고, 통신이 회복돼도 앱을 완전히 종료했다 켜기 전에는 빠져나올 길이
  /// 없다. 간격을 늘려 가며 몇 번 더 물어 스스로 회복하게 둔다.
  static const List<Duration> _retryDelays = [
    Duration(seconds: 3),
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(minutes: 2),
    Duration(minutes: 5),
  ];

  static const String _cacheKey = 'app_config.api_base_url';

  final _storage = const FlutterSecureStorage();

  String _apiBaseUrl = _fallbackBaseUrl;

  /// 이번 실행에서 쓸 서버 주소. 뒤에 슬래시가 없다(경로를 붙여 쓴다).
  String get apiBaseUrl => _apiBaseUrl;

  /// 주소를 어디서 얻었는지. 문제 추적용이며 동작에는 쓰지 않는다.
  String get source => _source;
  String _source = 'fallback';

  bool _initialized = false;

  /// 주소를 확정한다. 화면을 그리기 전에 한 번 부른다.
  ///
  /// 두 번 불러도 처음 한 번만 실제로 동작한다. 어떤 경로로도 예외를 밖으로
  /// 내보내지 않는다 — 주소를 못 정하는 것과 앱이 못 뜨는 것은 다른 문제다.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (_hasInjectedBaseUrl) {
      final injected = _normalize(_injectedBaseUrl);
      if (injected != null) {
        _apiBaseUrl = injected;
        _source = 'dart-define';
        return;
      }
      // 주었는데 쓸 수 없는 형태다(스킴 누락, 빈 값 등). 여기서 조용히
      // 원격으로 내려가면, 방금 띄운 로컬 서버를 보고 있다고 믿는 채로
      // 실제로는 게시된 주소를 호출하게 된다.
      debugPrint(
        'AppConfig: 주입된 주소를 쓸 수 없어 무시한다 '
        '(값="$_injectedBaseUrl" — http/https 스킴이 필요하다)',
      );
    }

    // 원격을 못 읽었을 때 곧바로 쓸 수 있도록 캐시를 먼저 깔아 둔다.
    final cached = _normalize(await _readCache(), requireHttps: true);
    if (cached != null) {
      _apiBaseUrl = cached;
      _source = 'cache';
    }

    final remote = _normalize(await _fetchRemote(), requireHttps: true);
    if (remote != null) {
      _apiBaseUrl = remote;
      _source = 'remote';
      if (remote != cached) {
        await _writeCache(remote);
      }
    }

    debugPrint('AppConfig: apiBaseUrl=$_apiBaseUrl (source=$_source)');

    // 원격까지 닿지 못했으면 뒤에서 다시 시도한다. 여기서 기다리지 않으므로
    // 첫 화면이 늦어지지 않고, 성공하면 그 뒤의 호출부터 새 주소를 쓴다
    // (주소는 호출 시점에 읽는다).
    if (_source != 'remote') {
      unawaited(_retryUntilRemote());
    }
  }

  /// 간격을 늘려 가며 원격 주소를 다시 물어본다. 한 번이라도 성공하면 끝난다.
  ///
  /// 목록을 다 쓰고도 못 받으면 멈춘다. 그 상황은 망이 없거나 설정을 게시하는
  /// 쪽이 내려간 것이고, 계속 두드려 봐야 배터리만 쓴다.
  Future<void> _retryUntilRemote() async {
    for (final delay in _retryDelays) {
      await Future<void>.delayed(delay);
      final remote = _normalize(await _fetchRemote(), requireHttps: true);
      if (remote == null) continue;
      final changed = remote != _apiBaseUrl;
      _apiBaseUrl = remote;
      _source = 'remote';
      await _writeCache(remote);
      debugPrint(
        'AppConfig: 뒤늦게 원격 주소 확보 apiBaseUrl=$remote'
        '${changed ? ' (바뀜)' : ''}',
      );
      return;
    }
    debugPrint('AppConfig: 원격 주소를 끝내 못 받았다 (현재=$_apiBaseUrl, source=$_source)');
  }

  /// 원격 설정에서 주소만 뽑아 온다. 실패는 전부 null 이다 — 이유별로
  /// 나눠 봐야 할 일이 같다(캐시나 기본값으로 내려간다).
  Future<String?> _fetchRemote() async {
    try {
      final response = await http
          .get(Uri.parse(_remoteConfigUrl))
          .timeout(_remoteTimeout);
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) return null;
      final value = decoded['api_base_url'];
      return value is String ? value : null;
    } catch (_) {
      return null;
    }
  }

  /// 쓸 수 있는 주소인지 보고, 쓸 수 있으면 형태를 하나로 맞춘다.
  ///
  /// 뒤 슬래시를 떼는 이유: 호출부가 `'$base/api/v1/...'` 로 이어 붙이는데,
  /// 슬래시가 남아 있으면 `//api/v1` 이 되어 서버가 다른 경로로 본다.
  ///
  /// requireHttps 를 켜면 평문 주소를 거른다. 원격 설정과 캐시에는 켜서 쓴다 —
  /// 그 값은 앱 밖에서 정해지므로, 평문을 허용하면 그 주소로 토큰이 그대로
  /// 나간다. 빌드할 때 박아 넣는 값에는 켜지 않는다. 개발 중에는 컴퓨터에
  /// 띄운 평문 서버를 봐야 하고, 그 값은 빌드하는 사람이 정한 것이다.
  static String? _normalize(String? raw, {bool requireHttps = false}) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    if (requireHttps && uri.scheme != 'https') return null;
    if (uri.host.isEmpty) return null;
    var normalized = trimmed;
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized.isEmpty ? null : normalized;
  }

  /// 주소 판정을 검사에서 그대로 부를 수 있게 열어 둔다. 이 판정이 무너지면
  /// 토큰이 어디로 나가는지가 바뀌는데, 그 사실은 화면만 봐서는 드러나지 않는다.
  @visibleForTesting
  static String? debugNormalize(String? raw, {bool requireHttps = false}) =>
      _normalize(raw, requireHttps: requireHttps);

  Future<String?> _readCache() async {
    try {
      return await _storage.read(key: _cacheKey);
    } catch (_) {
      // 저장소를 못 읽어도 원격이나 기본값으로 갈 수 있다.
      return null;
    }
  }

  Future<void> _writeCache(String value) async {
    try {
      await _storage.write(key: _cacheKey, value: value);
    } catch (_) {
      // 보관에 실패해도 이번 실행 동안은 메모리의 값으로 동작한다.
    }
  }
}

/// 서버 주소. 호출 시점에 확정된 값을 본다.
String get kApiBaseUrl => AppConfig.instance.apiBaseUrl;
