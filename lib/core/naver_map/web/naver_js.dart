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
}

@JS('naver.maps.Marker')
extension type JsMarker._(JSObject _) implements JSObject {
  external factory JsMarker(JSObject options);
  external void setMap(JsMap? map);
  external void setPosition(JsLatLng position);
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

/// Builds a plain JS object literal from Dart [entries], skipping null values.
JSObject jsObject(Map<String, JSAny?> entries) {
  final o = JSObject();
  for (final e in entries.entries) {
    final v = e.value;
    if (v != null) o[e.key] = v;
  }
  return o;
}
