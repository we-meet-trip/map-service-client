import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// 기기 저장소를 여는 공통 통로.
///
/// 상자 파일이 깨졌거나(쓰는 도중에 앱이 죽은 경우) 저장 공간이 없으면
/// `Hive.openBox` 가 던진다. 부팅 경로에서 그 예외가 그대로 올라가면 첫 화면이
/// 그려지기 전에 멈춰, 사용자는 시작 화면에 붙잡힌 앱을 보게 된다. 저장이
/// 안 되는 것과 앱이 열리지 않는 것 중에는 앞쪽이 낫다.
///
/// 깨진 파일은 한 번 지우고 다시 열어 본다. 그래도 안 되면 null 을 돌려주고,
/// 부르는 쪽은 저장 없이 그 실행을 버틴다.
Future<Box?> openLocalBox(String name) async {
  try {
    return await Hive.openBox(name);
  } catch (error) {
    debugPrint('[LocalBox] $name 열기 실패 → 지우고 다시 시도: $error');
  }
  try {
    await Hive.deleteBoxFromDisk(name);
    return await Hive.openBox(name);
  } catch (error) {
    debugPrint('[LocalBox] $name 복구 실패 → 저장 없이 진행: $error');
    return null;
  }
}
