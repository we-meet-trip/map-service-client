import 'package:hive_flutter/hive_flutter.dart';

/// 접근 권한 고지를 확인했는지 기기에 남긴다.
///
/// 한 번 확인하면 다시 묻지 않아야 하므로 앱을 지우기 전까지 남는 곳에 적는다.
class PermissionNoticeStore {
  PermissionNoticeStore._();
  static final PermissionNoticeStore instance = PermissionNoticeStore._();

  static const _boxName = 'permission_notice';
  static const _key = 'confirmed';
  static Box? _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  Box get _b => _box!;

  /// init 없이 읽히면(위젯 시험처럼) 미확인으로 본다. 앱에서는 부팅 때
  /// 항상 init 이 먼저 돈다.
  bool get confirmed => _box?.get(_key, defaultValue: false) as bool? ?? false;

  Future<void> confirm() => _b.put(_key, true);
}
