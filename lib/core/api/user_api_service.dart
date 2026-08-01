import 'api_client.dart';

/// 내 정보 조회·수정.
///
/// 마이페이지의 프로필 편집과 관심사 설정 화면이 쓴다. 두 경로 모두 토큰이
/// 반드시 필요하다.
class UserApiService {
  UserApiService._();
  static final UserApiService instance = UserApiService._();

  final _api = ApiClient.instance;

  Future<UserProfile> me() async {
    return UserProfile.fromJson(await _api.get('/api/v1/users/me'));
  }

  /// 바꿀 항목만 보낸다.
  ///
  /// 보내지 않은 항목은 서버가 그대로 둔다 — 프로필 편집과 관심사 설정이
  /// 다른 화면이라, 한쪽이 다른 쪽 값을 지우면 안 된다. 목록을 비우려면
  /// 빈 목록을 보낸다.
  Future<UserProfile> update({
    String? nickname,
    String? profileImageUrl,
    DateTime? birthDate,
    String? gender,
    List<String>? interests,
    List<String>? themes,
  }) async {
    final body = <String, dynamic>{};
    if (nickname != null) body['nickname'] = nickname;
    if (profileImageUrl != null) body['profileImageUrl'] = profileImageUrl;
    if (birthDate != null) body['birthDate'] = _fmtDate(birthDate);
    if (gender != null) body['gender'] = gender;
    if (interests != null) body['interests'] = interests;
    if (themes != null) body['themes'] = themes;
    return UserProfile.fromJson(
        await _api.patch('/api/v1/users/me', body: body));
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';
}

/// 서버가 보관 중인 내 정보.
class UserProfile {
  final int id;
  final String? email;
  final String nickname;
  final String? profileImageUrl;
  final DateTime? birthDate;
  final String? gender;
  final List<String> interests;
  final List<String> themes;

  const UserProfile({
    required this.id,
    required this.email,
    required this.nickname,
    required this.profileImageUrl,
    required this.birthDate,
    required this.gender,
    required this.interests,
    required this.themes,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as int,
        email: json['email'] as String?,
        nickname: json['nickname'] as String? ?? '',
        profileImageUrl: json['profileImageUrl'] as String?,
        birthDate: json['birthDate'] is String
            ? DateTime.tryParse(json['birthDate'] as String)
            : null,
        gender: json['gender'] as String?,
        interests: (json['interests'] as List<dynamic>?)
                ?.whereType<String>()
                .toList() ??
            const [],
        themes:
            (json['themes'] as List<dynamic>?)?.whereType<String>().toList() ??
                const [],
      );
}
