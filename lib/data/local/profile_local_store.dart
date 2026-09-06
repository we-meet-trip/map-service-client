import 'package:hive_flutter/hive_flutter.dart';
import '../../core/state/user_repository.dart';
import '../../core/state/auth_store.dart';
import '../../core/config/app_config.dart';

class ProfileLocalStore {
  ProfileLocalStore._();
  static final ProfileLocalStore instance = ProfileLocalStore._();

  static const _boxName = 'user_profile';
  String get _key =>
      'profile:${AppConfig.instance.storageScope}:${AuthStore.instance.userId ?? 'guest'}';
  static Box? _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  UserProfile? load() {
    final raw = _box?.get(_key);
    if (raw == null) return null;
    return _fromMap(Map<String, dynamic>.from(raw as Map));
  }

  Future<void> save(UserProfile p) async {
    await _box?.put(_key, _toMap(p));
  }

  Future<void> clear() async {
    await _box?.delete(_key);
    await _box?.delete('profile');
  }

  Map<String, dynamic> _toMap(UserProfile p) => {
    'id': p.id,
    'nickname': p.nickname,
    'birthdate': p.birthdate?.millisecondsSinceEpoch,
    'gender': p.gender,
    'interests': p.interests,
    'themes': p.themes,
    'profileImagePath': p.profileImagePath,
    'englishName': p.englishName,
    'phone': p.phone,
    'email': p.email,
    'homeAddress': p.homeAddress,
    'otherAddresses': p.otherAddresses
        .map((a) => {'name': a.name, 'address': a.address})
        .toList(),
    'notificationsEnabled': p.notificationsEnabled,
  };

  UserProfile _fromMap(Map<String, dynamic> m) {
    final rawMs = m['birthdate'];
    final addresses = (m['otherAddresses'] as List? ?? [])
        .map(
          (e) => NamedAddress(
            name: (e as Map)['name'] as String,
            address: e['address'] as String,
          ),
        )
        .toList();
    return UserProfile(
      id: m['id'] as String,
      nickname: m['nickname'] as String? ?? '',
      birthdate: rawMs != null
          ? DateTime.fromMillisecondsSinceEpoch(rawMs as int)
          : null,
      gender: m['gender'] as String?,
      interests: List<String>.from(m['interests'] as List? ?? []),
      themes: List<String>.from(m['themes'] as List? ?? []),
      profileImagePath: m['profileImagePath'] as String?,
      englishName: m['englishName'] as String?,
      phone: m['phone'] as String?,
      email: m['email'] as String?,
      homeAddress: m['homeAddress'] as String?,
      otherAddresses: addresses,
      notificationsEnabled: m['notificationsEnabled'] as bool? ?? true,
    );
  }
}
