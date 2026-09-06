import 'package:web/web.dart' as web;

void setMapPointerEnabled(bool enabled) {
  final maps = web.document.querySelectorAll('.gm-style');
  for (var i = 0; i < maps.length; i++) {
    final element = maps.item(i) as web.HTMLElement?;
    if (element != null) {
      element.style.pointerEvents = enabled ? 'auto' : 'none';
    }
  }
}
