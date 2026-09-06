import 'package:flutter/foundation.dart';
import 'map_pointer_native.dart'
    if (dart.library.js_interop) 'map_pointer_web.dart'
    as platform;

final ValueNotifier<bool> mapPointerEnabled = ValueNotifier(true);

void setMapPointerEnabled(bool enabled) {
  mapPointerEnabled.value = enabled;
  platform.setMapPointerEnabled(enabled);
}
