import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/common/utils/korea_bounds.dart';

/// 서비스 범위 밖 좌표를 대표 지점으로 갈음한다.
///
/// 갈음하지 않고 그대로 물으면 서버가 좌표 검증에서 거절해, 화면이 그것을
/// 조회 실패로 적는다 — 실제로는 물어볼 수 없는 자리일 뿐이다. 갈음했다는
/// 사실을 함께 돌려주어야 화면이 서울 자료를 자기 주변 자료로 보여 주지 않는다.
void main() {
  test('범위 안 좌표는 그대로 쓰고 갈음했다고 말하지 않는다', () {
    expect(KoreaBounds.clampToService(37.5665, 126.9780), (
      37.5665,
      126.9780,
      false,
    ));
    // 경계값은 범위 안이다.
    expect(KoreaBounds.clampToService(33, 124).$3, isFalse);
    expect(KoreaBounds.clampToService(43, 132).$3, isFalse);
  });

  test('범위 밖 좌표는 대표 지점으로 갈음하고 그 사실을 알린다', () {
    // 쿠퍼티노 — 심사자가 위치를 켠 채 이동수단 화면을 여는 경우다.
    expect(KoreaBounds.clampToService(37.33, -122.03), (
      KoreaBounds.fallbackLat,
      KoreaBounds.fallbackLng,
      true,
    ));
    // 경계 바로 밖.
    for (final outside in const [
      (32.9, 126.9),
      (43.1, 126.9),
      (37.5, 123.9),
      (37.5, 132.1),
    ]) {
      final result = KoreaBounds.clampToService(outside.$1, outside.$2);
      expect(result.$3, isTrue, reason: '$outside 는 범위 밖이다');
      expect(result.$1, KoreaBounds.fallbackLat);
      expect(result.$2, KoreaBounds.fallbackLng);
    }
  });
}
