import 'package:flutter/foundation.dart';
import '../../data/local/profile_local_store.dart';

class UserRepository {
  UserRepository._() {
    profile.addListener(_persist);
  }
  static final UserRepository instance = UserRepository._();

  final ValueNotifier<UserProfile> profile = ValueNotifier(UserProfile.empty());

  static Future<void> init() async {
    final saved = ProfileLocalStore.instance.load();
    instance.profile.value = saved ?? UserProfile.empty();
  }

  void _persist() => ProfileLocalStore.instance.save(profile.value);

  void updateNickname(String nickname) {
    profile.value = profile.value.copyWith(nickname: nickname);
  }

  /// 서버가 보관 중인 계정 정보를 화면용 프로필에 맞춘다.
  ///
  /// 로그인 직후와 앱 시작 복원 뒤에 부른다. 그 전에는 가입 화면을 거친
  /// 사용자만 이름을 갖고 있어, 이미 있는 계정으로 로그인하면 화면이 계속
  /// 기본 이름을 보여 줬다.
  ///
  /// 항목마다 따로 넣지 않고 한 번에 넣는다 — 넣을 때마다 저장과 다시 그리기가
  /// 일어나기 때문이다.
  ///
  /// null 인 항목은 건드리지 않는다. 로그인 응답처럼 이름만 아는 경우가 있고,
  /// 그때 나머지를 함께 지우면 이미 갖고 있던 값이 사라진다.
  void applyAccount({
    String? nickname,
    String? email,
    DateTime? birthdate,
    String? gender,
    List<String>? interests,
    List<String>? themes,
  }) {
    profile.value = profile.value.copyWith(
      nickname: (nickname == null || nickname.isEmpty) ? null : nickname,
      email: email,
      birthdate: birthdate,
      gender: gender,
      interests: interests,
      themes: themes,
    );
  }

  /// 다음 계정에 사진·연락처·주소를 포함한 개인 정보를 넘기지 않는다.
  Future<void> clearAccount() async {
    profile.value = UserProfile.empty();
    signUpEmail = null;
    signUpPassword = null;
    await ProfileLocalStore.instance.clear();
  }

  void updateBirthGender({DateTime? birthdate, String? gender}) {
    profile.value = profile.value.copyWith(
      birthdate: birthdate,
      gender: gender,
    );
  }

  void updateInterests(List<String> interests) {
    profile.value = profile.value.copyWith(interests: interests);
  }

  /// 여행 테마. 관심사와 같은 단계에서 함께 고르고 함께 서버로 보낸다.
  void updateThemes(List<String> themes) {
    profile.value = profile.value.copyWith(themes: themes);
  }

  /// 가입 요청에 쓸 계정 정보. 서버로 보내고 나면 화면에 남기지 않는다.
  String? signUpEmail;
  String? signUpPassword;

  void updateProfileImage(String? imagePath) {
    profile.value = profile.value.copyWith(
      profileImagePath: imagePath,
      clearImage: imagePath == null,
    );
  }

  void updateEnglishName(String? englishName) {
    profile.value = profile.value.copyWith(englishName: englishName);
  }

  void updatePhone(String? phone) {
    profile.value = profile.value.copyWith(phone: phone);
  }

  void updateEmail(String? email) {
    profile.value = profile.value.copyWith(email: email);
  }

  void updateHomeAddress(String? homeAddress) {
    profile.value = profile.value.copyWith(homeAddress: homeAddress);
  }

  void updateNotificationsEnabled(bool enabled) {
    profile.value = profile.value.copyWith(notificationsEnabled: enabled);
  }

  void addOtherAddress(NamedAddress address) {
    profile.value = profile.value.copyWith(
      otherAddresses: [...profile.value.otherAddresses, address],
    );
  }

  void updateOtherAddress(int index, NamedAddress address) {
    final list = [...profile.value.otherAddresses];
    list[index] = address;
    profile.value = profile.value.copyWith(otherAddresses: list);
  }

  void removeOtherAddress(int index) {
    final list = [...profile.value.otherAddresses]..removeAt(index);
    profile.value = profile.value.copyWith(otherAddresses: list);
  }
}

class NamedAddress {
  final String name;
  final String address;

  const NamedAddress({required this.name, required this.address});
}

class UserProfile {
  final String id;
  final String nickname;
  final DateTime? birthdate;
  final String? gender;
  final List<String> interests;

  /// 여행 테마. 관심사와 함께 골라 함께 서버에 저장한다.
  final List<String> themes;
  final String? profileImagePath;
  final String? englishName;
  final String? phone;
  final String? email;
  final String? homeAddress;
  final List<NamedAddress> otherAddresses;
  final bool notificationsEnabled;

  const UserProfile({
    required this.id,
    required this.nickname,
    this.birthdate,
    this.gender,
    this.interests = const [],
    this.themes = const [],
    this.profileImagePath,
    this.englishName,
    this.phone,
    this.email,
    this.homeAddress,
    this.otherAddresses = const [],
    this.notificationsEnabled = true,
  });

  factory UserProfile.empty() => UserProfile(
    id: 'local_${DateTime.now().millisecondsSinceEpoch}',
    nickname: '',
  );

  /// 화면에 보여 줄 이름.
  ///
  /// 로그인 전이거나 아직 서버에서 이름을 받지 못했을 때 쓸 기본 이름을 여기서
  /// 한 번만 정한다. 화면마다 따로 정하면 같은 사람을 홈과 마이페이지가 다르게
  /// 부르게 된다.
  String get displayName => nickname.isEmpty ? '여행자' : nickname;

  UserProfile copyWith({
    String? nickname,
    DateTime? birthdate,
    String? gender,
    List<String>? interests,
    List<String>? themes,
    String? profileImagePath,
    bool clearImage = false,
    String? englishName,
    String? phone,
    String? email,
    String? homeAddress,
    List<NamedAddress>? otherAddresses,
    bool? notificationsEnabled,
  }) {
    return UserProfile(
      id: id,
      nickname: nickname ?? this.nickname,
      birthdate: birthdate ?? this.birthdate,
      gender: gender ?? this.gender,
      interests: interests ?? this.interests,
      themes: themes ?? this.themes,
      profileImagePath: clearImage
          ? null
          : (profileImagePath ?? this.profileImagePath),
      englishName: englishName ?? this.englishName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      homeAddress: homeAddress ?? this.homeAddress,
      otherAddresses: otherAddresses ?? this.otherAddresses,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}
