import 'package:flutter/foundation.dart';

class UserRepository {
  UserRepository._();
  static final UserRepository instance = UserRepository._();

  final ValueNotifier<UserProfile> profile = ValueNotifier(UserProfile.empty());

  void updateNickname(String nickname) {
    profile.value = profile.value.copyWith(nickname: nickname);
  }

  void updateBirthGender({DateTime? birthdate, String? gender}) {
    profile.value = profile.value.copyWith(birthdate: birthdate, gender: gender);
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

  factory UserProfile.empty() => const UserProfile(nickname: '');

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
      nickname: nickname ?? this.nickname,
      birthdate: birthdate ?? this.birthdate,
      gender: gender ?? this.gender,
      interests: interests ?? this.interests,
      themes: themes ?? this.themes,
      profileImagePath: clearImage ? null : (profileImagePath ?? this.profileImagePath),
      englishName: englishName ?? this.englishName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      homeAddress: homeAddress ?? this.homeAddress,
      otherAddresses: otherAddresses ?? this.otherAddresses,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}
