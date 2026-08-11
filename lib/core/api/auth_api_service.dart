import 'dart:async';

import '../state/auth_store.dart';
// UserProfile 이라는 이름이 화면용과 서버용 두 곳에 있어, 여기서는 보관소만 들인다.
import '../state/user_repository.dart' show UserRepository;
import 'api_client.dart';
import 'user_api_service.dart';

/// 회원가입·로그인·토큰 갱신·로그아웃을 다룬다.
///
/// 응답으로 받은 토큰은 이 서비스가 보관소에 넣는다 — 화면마다 따로 넣으면
/// 한 곳을 빠뜨렸을 때 로그인한 사용자가 로그인하지 않은 것으로 보인다.
///
/// 인증 경로의 필드 표기는 낙타 표기다(다른 경로는 밑줄 표기를 쓴다).
class AuthApiService {
  AuthApiService._();
  static final AuthApiService instance = AuthApiService._();

  final _api = ApiClient.instance;

  /// 앱 시작 때 한 번 부른다. 저장된 토큰을 되살리고, 만료 시 갱신할 방법을
  /// 보관소에 꽂아 준다.
  Future<void> bootstrap() async {
    AuthStore.instance.refreshHandler = _refreshTokens;
    await AuthStore.instance.restore();
    if (AuthStore.instance.isLoggedIn.value) {
      _syncProfile();
    }
  }

  /// 이메일 회원가입.
  ///
  /// 가입 화면이 단계별로 모은 값을 한 번에 보낸다. 뒤 단계를 건너뛰어
  /// 비어 있는 항목은 아예 싣지 않는다 — 서버에서 선택 항목이다.
  Future<void> signUp({
    required String email,
    required String password,
    required String nickname,
    DateTime? birthDate,
    String? gender,
    List<String>? interests,
    List<String>? themes,
  }) async {
    final body = <String, dynamic>{
      'email': email,
      'password': password,
      'nickname': nickname,
    };
    if (birthDate != null) body['birthDate'] = _fmtDate(birthDate);
    if (gender != null && gender.isNotEmpty) body['gender'] = gender;
    if (interests != null && interests.isNotEmpty) {
      body['interests'] = interests;
    }
    if (themes != null && themes.isNotEmpty) body['themes'] = themes;

    final json = await _api.post('/api/v1/auth/signup', body: body);
    await AuthStore.instance.save(AuthTokens.fromJson(json));
    _syncProfile();
  }

  /// 이메일 로그인.
  Future<void> login({
    required String email,
    required String password,
  }) async {
    final json = await _api.post('/api/v1/auth/login', body: {
      'email': email,
      'password': password,
    });
    await AuthStore.instance.save(AuthTokens.fromJson(json));
    _syncProfile();
  }

  /// 카카오 인가 화면 주소를 받는다.
  ///
  /// state 는 요청과 복귀를 짝지어 확인하는 값이다. 이 값이 되돌아온 것과
  /// 다르면 내가 시작하지 않은 로그인이므로 버려야 한다.
  Future<String> kakaoAuthorizeUrl(String state) async {
    final json = await _api.get('/api/v1/auth/kakao', query: {'state': state});
    return json['authorizeUrl'] as String;
  }

  /// 카카오가 돌려준 인가 코드를 토큰으로 바꾼다.
  Future<void> kakaoLogin(String code) async {
    final json = await _api.post('/api/v1/auth/kakao/callback', body: {
      'code': code,
    });
    await AuthStore.instance.save(AuthTokens.fromJson(json));
    _syncProfile();
  }

  /// 로그아웃. 서버 호출이 실패해도 기기의 토큰은 반드시 버린다 —
  /// 남겨 두면 로그아웃한 사용자가 계속 로그인 상태로 보인다.
  Future<void> logout() async {
    try {
      await _api.post('/api/v1/auth/logout');
    } on ApiException {
      // 이미 만료됐거나 서버가 응답하지 않아도 아래에서 정리한다.
    } finally {
      await AuthStore.instance.clear();
      UserRepository.instance.clearAccount();
    }
  }

  /// 로그인한 사람의 정보를 화면용 프로필에 맞춘다.
  ///
  /// 두 걸음으로 나눈다. 인증 응답에 이미 들어 있는 이름을 먼저 넣어 화면이
  /// 곧바로 제 이름을 그리게 하고, 나머지 항목은 뒤에서 조용히 받아 채운다.
  ///
  /// 뒤 호출을 기다리지 않는 이유는 앱 시작과 로그인 직후가 네트워크 응답을
  /// 기다리며 멈춰서는 안 되기 때문이다. 그래서 이 함수는 값을 돌려주지 않고,
  /// 결과는 보관소를 듣고 있는 화면이 받는다.
  void _syncProfile() {
    final nickname = AuthStore.instance.nickname;
    if (nickname != null && nickname.isNotEmpty) {
      UserRepository.instance.applyAccount(nickname: nickname);
    }
    unawaited(_fetchAccount());
  }

  Future<void> _fetchAccount() async {
    try {
      final me = await UserApiService.instance.me();
      UserRepository.instance.applyAccount(
        nickname: me.nickname,
        email: me.email,
        birthdate: me.birthDate,
        gender: me.gender,
        interests: me.interests,
        themes: me.themes,
      );
    } catch (_) {
      // 못 받아도 앞 걸음에서 넣은 이름과 기기에 저장해 둔 값으로 화면은
      // 그대로 나간다. 여기서 화면에 알리면 시작할 때마다 오류가 뜬다.
    }
  }

  /// 보관소가 만료를 만났을 때 부르는 갱신부.
  ///
  /// 여기서 토큰을 보관소에 넣지 않는다. 보관소가 결과를 받아 직접 넣는다 —
  /// 갱신이 여러 번 겹쳐 들어와도 저장이 한 번만 일어나게 하기 위함이다.
  Future<AuthTokens?> _refreshTokens(String refreshToken) async {
    try {
      final json = await _api.post('/api/v1/auth/token/refresh', body: {
        'refreshToken': refreshToken,
      });
      return AuthTokens.fromJson(json);
    } on ApiException {
      return null;
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';
}
