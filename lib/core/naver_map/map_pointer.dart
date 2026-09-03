/// 지도가 포인터를 받을지 여는 스위치.
///
/// 웹 지도는 화면에 직접 얹히는 요소라, 그 위에 시트를 띄워도 손짓이 지도로
/// 먼저 간다. 시트가 떠 있는 동안 지도를 잠가 두면 손짓이 시트에 닿는다.
/// 앱에서는 지도가 화면 안에서 그려지므로 아무것도 하지 않는다.
library;

export 'map_pointer_web.dart' if (dart.library.io) 'map_pointer_noop.dart';
