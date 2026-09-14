import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/features/vision/models/vision_models.dart';

/// 장소 인식에 싣는 좌표가 서비스 범위를 벗어나면 실지 않는다.
///
/// 범위 밖 좌표를 실으면 요청 전체가 거절되어 사진 인식 자체가 되지 않는다.
/// 국외에서 위치를 켠 사용자도 위치 없이 인식은 그대로 쓸 수 있어야 한다.
void main() {
  test('서비스 범위 안의 좌표는 그대로 싣는다', () {
    final seoul = VisionLocation.inServiceArea(37.5665, 126.9780);
    expect(seoul, isNotNull);
    expect(seoul!.toJson(), {'lat': 37.5665, 'lng': 126.9780});

    expect(VisionLocation.inServiceArea(33, 124), isNotNull);
    expect(VisionLocation.inServiceArea(43, 132), isNotNull);
  });

  test('서비스 범위 밖의 좌표는 싣지 않는다', () {
    // 미국 서부 — 심사자가 위치를 켠 채 장소 인식을 여는 경우다.
    expect(VisionLocation.inServiceArea(37.7749, -122.4194), isNull);
    // 경계 바로 밖.
    expect(VisionLocation.inServiceArea(32.9, 126.9), isNull);
    expect(VisionLocation.inServiceArea(43.1, 126.9), isNull);
    expect(VisionLocation.inServiceArea(37.5, 123.9), isNull);
    expect(VisionLocation.inServiceArea(37.5, 132.1), isNull);
  });
}
