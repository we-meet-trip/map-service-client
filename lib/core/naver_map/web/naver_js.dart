// dart:js_interop bindings for the Naver Maps JavaScript API v3.
//
// Web-only: this file is reached solely through the adapter's conditional
// export on the web target, so it may use dart:js_interop / package:web
// without platform guards.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;

@JS('naver.maps.LatLng')
extension type JsLatLng._(JSObject _) implements JSObject {
  external factory JsLatLng(num lat, num lng);
  external double lat();
  external double lng();
}

@JS('naver.maps.LatLngBounds')
extension type JsLatLngBounds._(JSObject _) implements JSObject {
  external factory JsLatLngBounds(JsLatLng sw, JsLatLng ne);
}

@JS('naver.maps.Point')
extension type JsPoint._(JSObject _) implements JSObject {
  external factory JsPoint(num x, num y);
}

@JS('naver.maps.Map')
extension type JsMap._(JSObject _) implements JSObject {
  external factory JsMap(web.HTMLElement element, JSObject options);
  external void setZoom(int zoom, [bool effect]);
  external double getZoom();
  external JsLatLng getCenter();
  external void fitBounds(JsLatLngBounds bounds, [JSAny? margin]);
  external void morph(JsLatLng latlng, int zoom, [JSObject? transition]);

  /// 상자 재측정 + 오버레이 재배치까지 수행.
  /// 'resize' 통지는 타일만 옮기고 마커·선은 두고 간다.
  external void refresh([bool noEffect]);
}

@JS('naver.maps.Marker')
extension type JsMarker._(JSObject _) implements JSObject {
  external factory JsMarker(JSObject options);
  external void setMap(JsMap? map);
  external void setPosition(JsLatLng position);
  // 아이콘을 통째로 갈아 끼운다. 마커를 회전시키는 길이 이것뿐이라 — 각도는
  // 아이콘 내용(HTML)의 변형으로 들어간다 — 방향이 바뀔 때마다 여기를 부른다.
  external void setIcon(JSObject icon);
}

@JS('naver.maps.Polyline')
extension type JsPolyline._(JSObject _) implements JSObject {
  external factory JsPolyline(JSObject options);
  external void setMap(JsMap? map);
}

@JS('naver.maps.Polygon')
extension type JsPolygon._(JSObject _) implements JSObject {
  external factory JsPolygon(JSObject options);
  external void setMap(JsMap? map);
}

/// `naver.maps.Event.trigger(instance, eventName)` — used to fire a 'resize' so
/// the map re-measures its container after layout settles.
@JS('naver.maps.Event.trigger')
external void naverEventTrigger(JSObject instance, String eventName);

/// `naver.maps.Event.addListener(instance, eventName, handler)` — used to catch
/// marker clicks. The returned handle is what removeListener takes.
@JS('naver.maps.Event.addListener')
external JSAny naverEventAddListener(
  JSObject instance,
  String eventName,
  JSFunction handler,
);

/// Detaches a listener registered with [naverEventAddListener]. Without this the
/// handler keeps the removed marker (and the widget state it closes over) alive.
@JS('naver.maps.Event.removeListener')
external void naverEventRemoveListener(JSAny listener);

/// Builds a plain JS object literal from Dart [entries], skipping null values.
JSObject jsObject(Map<String, JSAny?> entries) {
  final o = JSObject();
  for (final e in entries.entries) {
    final v = e.value;
    if (v != null) o[e.key] = v;
  }
  return o;
}
