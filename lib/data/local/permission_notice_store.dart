import 'package:hive_flutter/hive_flutter.dart';

import 'local_box.dart';

/// 접근 권한 고지를 확인했는지 기기에 남긴다.
///
/// 한 번 확인하면 다시 묻지 않아야 하므로 앱을 지우기 전까지 남는 곳에 적는다.
class PermissionNoticeStore {
  PermissionNoticeStore._();
  static final PermissionNoticeStore instance = PermissionNoticeStore._();

  static const _boxName = 'permission_notice';
  static const _key = 'confirmed';
  static Box? _box;

  /// 상자를 못 열었을 때 이 실행 동안만 쓰는 기억.
  ///
  /// 없으면 확인을 눌러도 상태가 바뀌지 않아, 관문이 모든 화면을 고지 화면으로
  /// 되돌린다 — 빠져나올 수 없는 고리가 된다. 다음 실행에 상자를 다시 열어
  /// 보고, 열리면 그때 기기에 남는다.
  static bool _confirmedInMemory = false;

  static Future<void> init() async {
    _box = await openLocalBox(_boxName);
  }

  /// init 없이 읽히면(위젯 시험처럼) 미확인으로 본다. 앱에서는 부팅 때
  /// 항상 init 이 먼저 돈다.
  bool get confirmed =>
      _confirmedInMemory ||
      (_box?.get(_key, defaultValue: false) as bool? ?? false);

  Future<void> confirm() async {
    _confirmedInMemory = true;
    await _box?.put(_key, true);
  }
}
