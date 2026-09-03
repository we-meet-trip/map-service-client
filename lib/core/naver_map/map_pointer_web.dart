import 'package:flutter/foundation.dart';

/// 지도가 지금 손짓을 받아도 되는지.
///
/// 지도 요소는 화면에 직접 얹혀 있어, 그 위에 그려진 시트보다 손짓을 먼저
/// 가져간다. 시트가 떠 있는 동안 이 값을 꺼 두면 손짓이 시트로 넘어간다.
final ValueNotifier<bool> naverMapPointerEnabled = ValueNotifier(true);

void setNaverMapPointerEnabled(bool enabled) {
  naverMapPointerEnabled.value = enabled;
}
