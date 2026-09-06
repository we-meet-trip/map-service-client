import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';

/// 로그인 상태와 토큰을 한 곳에서 보관한다.
///
/// **로그인 여부의 단일 출처**다. 화면마다 따로 상태를 들면 한쪽만 갱신돼
/// 로그인한 사용자가 로그인 화면으로 튕기는 일이 생긴다. 로그인·가입 완료·
/// 앱 시작 복원 세 지점 모두 여기를 거친다.
///
/// 갱신 토큰은 쓸 때마다 새 쌍으로 바뀌고 **옛 것은 즉시 죽는다**. 이미 쓴
/// 갱신 토큰을 다시 보내면 서버가 그 사용자의 갱신 토큰을 전부 폐기해 강제
/// 로그아웃된다. 그래서 동시에 여러 요청이 만료를 만나도 갱신 호출은 하나로
/// 묶는다(`_refreshing`).
class AuthStore {
  AuthStore._();
  static final AuthStore instance = AuthStore._();

  static const _accessKey = 'auth.access_token';
  static const _refreshKey = 'auth.refresh_token';
  static const _userIdKey = 'auth.user_id';
  static const _nicknameKey = 'auth.nickname';

  final _storage = const FlutterSecureStorage();

  /// 로그인 여부. 화면이 이 값을 듣고 다시 그린다.
  final ValueNotifier<bool> isLoggedIn = ValueNotifier(false);

  String? _accessToken;
  String? _refreshToken;
  int? _userId;
  String? _nickname;
  int _sessionVersion = 0;
  String? _scope;
  Future<void> _persistence = Future<void>.value();

  int get sessionVersion => _sessionVersion;
  bool get _sameScope => _scope == AppConfig.instance.storageScope;
  String? get accessToken => _sameScope ? _accessToken : null;
  String? get refreshToken => _sameScope ? _refreshToken : null;
  int? get userId => _sameScope ? _userId : null;
  String? get nickname => _nickname;

  /// 진행 중인 갱신. 여러 요청이 동시에 만료를 만나도 이 하나를 함께 기다린다.
  Future<bool>? _refreshing;

  /// 갱신을 실제로 수행하는 함수. 인증 API 계층이 앱 시작 때 꽂아 준다.
  ///
  /// 여기서 인증 API 를 직접 부르지 않는 이유: 인증 API 는 요청마다 토큰을
  /// 붙이려고 이 보관소를 읽는다. 서로 마주 보게 두면 순환이 생긴다.
  Future<AuthTokens?> Function(String refreshToken)? refreshHandler;
  Future<void> Function()? onSessionCleared;

  /// 앱 시작 때 저장소에서 토큰을 되살린다.
  ///
  /// 토큰의 만료를 여기서 따지지 않는다 — 만료 여부는 서버가 판정하고,
  /// 클라이언트는 401 을 받았을 때 갱신한다. 여기서 미리 재려 하면 기기
  /// 시계가 틀어졌을 때 멀쩡한 토큰을 버리게 된다.
  Future<void> restore() async {
    final version = _sessionVersion;
    final scope = AppConfig.instance.storageScope;
    final values = await Future.wait([
      _read('$scope.$_accessKey'),
      _read('$scope.$_refreshKey'),
      _read('$scope.$_userIdKey'),
      _read('$scope.$_nicknameKey'),
    ]);
    if (version != _sessionVersion ||
        scope != AppConfig.instance.storageScope) {
      return;
    }
    _scope = scope;
    _accessToken = values[0];
    _refreshToken = values[1];
    final rawUserId = values[2];
    _userId = rawUserId == null ? null : int.tryParse(rawUserId);
    _nickname = values[3];
    isLoggedIn.value = _accessToken != null && _refreshToken != null;
  }

  /// 로그인·가입 성공 결과를 보관한다.
  Future<void> save(AuthTokens tokens) async {
    _sessionVersion++;
    _refreshing = null;
    await _saveTokens(tokens);
  }

  Future<void> _saveTokens(AuthTokens tokens) async {
    final version = _sessionVersion;
    final scope = AppConfig.instance.storageScope;
    _scope = scope;
    _accessToken = tokens.accessToken;
    _refreshToken = tokens.refreshToken;
    _userId = tokens.userId;
    _nickname = tokens.nickname;
    isLoggedIn.value = true;
    await _persist(() async {
      if (version != _sessionVersion) return;
      await _write('$scope.$_accessKey', tokens.accessToken);
      await _write('$scope.$_refreshKey', tokens.refreshToken);
      await _write('$scope.$_userIdKey', tokens.userId?.toString());
      await _write('$scope.$_nicknameKey', tokens.nickname);
    });
  }

  /// 화면에서 바꾼 닉네임을 반영한다(토큰은 그대로).
  Future<void> updateNickname(String nickname) async {
    final scope = _scope;
    final version = _sessionVersion;
    _nickname = nickname;
    await _persist(() async {
      if (scope != null && version == _sessionVersion) {
        await _write('$scope.$_nicknameKey', nickname);
      }
    });
  }

  /// 토큰을 모두 버리고 로그아웃 상태로 만든다.
  Future<void> clear() async {
    final scope = _scope ?? AppConfig.instance.storageScope;
    final clearingAccount = onSessionCleared?.call();
    _sessionVersion++;
    _refreshing = null;
    _accessToken = null;
    _refreshToken = null;
    _userId = null;
    _nickname = null;
    isLoggedIn.value = false;
    await _persist(() async {
      for (final key in [_accessKey, _refreshKey, _userIdKey, _nicknameKey]) {
        await _write('$scope.$key', null);
        // 이전 설치본의 환경 구분 없는 토큰은 다시 사용하지 않는다.
        await _write(key, null);
      }
    });
    await clearingAccount;
  }

  /// 액세스 토큰을 새로 받는다. 이미 갱신 중이면 그 결과를 함께 기다린다.
  ///
  /// 반환: 갱신에 성공했으면 true. 실패하면 토큰을 버리고 false 를 준다 —
  /// 이때 화면은 로그인부터 다시 받아야 한다.
  Future<bool> refresh() {
    final active = _refreshing;
    if (active != null) return active;
    late final Future<bool> pending;
    pending = _runRefresh().whenComplete(() {
      if (identical(_refreshing, pending)) _refreshing = null;
    });
    _refreshing = pending;
    return pending;
  }

  Future<bool> _runRefresh() async {
    final token = refreshToken;
    final version = _sessionVersion;
    final scope = AppConfig.instance.storageScope;
    final handler = refreshHandler;
    if (token == null || handler == null) {
      return false;
    }
    AuthTokens? tokens;
    try {
      tokens = await handler(token);
    } catch (_) {
      tokens = null;
    }
    if (version != _sessionVersion ||
        scope != AppConfig.instance.storageScope) {
      return false;
    }
    if (tokens == null) {
      // 갱신이 거절됐다는 것은 이 토큰으로는 더 이상 아무것도 못 한다는 뜻이다.
      await clear();
      return false;
    }
    await _saveTokens(tokens);
    return version == _sessionVersion &&
        scope == AppConfig.instance.storageScope;
  }

  Future<void> _persist(Future<void> Function() operation) {
    // 저장·삭제를 직렬화하여 늦게 끝난 갱신 쓰기가 로그아웃 뒤 토큰을 살리지 못한다.
    return _persistence = _persistence.then((_) => operation());
  }

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      // 저장소를 못 읽으면 로그인하지 않은 것으로 본다. 여기서 던지면
      // 앱이 시작조차 못 한다.
      return null;
    }
  }

  Future<void> _write(String key, String? value) async {
    try {
      if (value == null) {
        await _storage.delete(key: key);
      } else {
        await _storage.write(key: key, value: value);
      }
    } catch (_) {
      // 보관에 실패해도 이번 실행 동안은 메모리의 값으로 동작한다.
    }
  }
}

/// 인증 응답에서 뽑아 낸 토큰 한 벌.
class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final int? userId;
  final String? nickname;

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.userId,
    this.nickname,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return AuthTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      userId: user?['id'] as int?,
      nickname: user?['nickname'] as String?,
    );
  }
}
