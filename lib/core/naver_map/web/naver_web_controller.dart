// Web implementation of NaverMapController: translates the Flutter-facing
// overlay/camera model (defined in naver_map_stub.dart) into Naver Maps
// JavaScript API v3 overlays on a JsMap. Web-only (see naver_js.dart header).
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../../common/theme/app_colors.dart';
import '../naver_map_stub.dart';
import 'naver_js.dart';

/// Controls a single Naver JS map instance and its overlays.
class NaverMapController {
  NaverMapController.create(web.HTMLElement host, NaverMapViewOptions options)
      : _map = _createJsMap(host, options);

  final JsMap _map;
  final List<_Tracked> _overlays = [];

  /// Forces the map to re-measure its container. Naver caches the container
  /// size at creation time, so if the host element's size is established/changed
  /// after the map is built, tiles only fill the stale area until a 'resize'.
  void refresh() => naverEventTrigger(_map, 'resize');

  Future<void> addOverlay(dynamic overlay) async => _add(overlay);

  Future<void> addOverlayAll(Iterable<dynamic> overlays) async {
    for (final o in overlays) {
      _add(o);
    }
  }

  /// Removes tracked overlays. With [type] given, only overlays of that type
  /// (currently just polygons) are removed; otherwise all are removed.
  Future<void> clearOverlays({NOverlayType? type}) async {
    _overlays.removeWhere((t) {
      if (type != null && t.type != type) return false;
      t.remove();
      return true;
    });
  }

  Future<void> updateCamera(NCameraUpdate update) async {
    switch (update.kind) {
      case NCameraUpdateKind.fitBounds:
        final b = update.bounds!;
        final bounds = JsLatLngBounds(
          JsLatLng(b.southWest.latitude, b.southWest.longitude),
          JsLatLng(b.northEast.latitude, b.northEast.longitude),
        );
        // A number margin applies uniform padding (px) on every side.
        _map.fitBounds(bounds, (update.padding?.top ?? 0.0).toJS);
      case NCameraUpdateKind.fromPosition:
        final p = update.position!;
        _map.morph(
          JsLatLng(p.target.latitude, p.target.longitude),
          p.zoom.round(),
        );
      case NCameraUpdateKind.zoomIn:
        _map.setZoom(_map.getZoom().round() + 1, true);
      case NCameraUpdateKind.zoomOut:
        _map.setZoom(_map.getZoom().round() - 1, true);
    }
  }

  void _add(dynamic overlay) {
    if (overlay is NMarker) {
      _addMarker(overlay);
    } else if (overlay is NPathOverlay) {
      _addPath(overlay);
    } else if (overlay is NPolylineOverlay) {
      _addPolyline(overlay);
    } else if (overlay is NPolygonOverlay) {
      _addPolygon(overlay);
    }
  }

  void _addMarker(NMarker m) {
    final marker = JsMarker(jsObject({
      'position': JsLatLng(m.position.latitude, m.position.longitude),
      'map': _map,
      'icon': jsObject({
        'content': _markerHtml(_labelFromId(m.id)).toJS,
        'anchor': JsPoint(18, 18),
      }),
    }));
    _overlays.add(_Tracked(() => marker.setMap(null), null));
  }

  void _addPath(NPathOverlay p) {
    final color = p.color ?? AppColors.primaryScale[400]!;
    final width = (p.width ?? 4).round();
    // Naver polylines have no separate outline; emulate the white casing with a
    // wider stroke underneath, then the colored stroke on top.
    if (p.outlineColor != null && (p.outlineWidth ?? 0) > 0) {
      final casing = JsPolyline(jsObject({
        'map': _map,
        'path': _toJsCoords(p.coords),
        'strokeColor': _hex(p.outlineColor!).toJS,
        'strokeWeight': (width + 2 * (p.outlineWidth ?? 2.0)).round().toJS,
        'strokeOpacity': 1.0.toJS,
        'strokeLineCap': 'round'.toJS,
        'strokeLineJoin': 'round'.toJS,
      }));
      _overlays.add(_Tracked(() => casing.setMap(null), null));
    }
    final line = JsPolyline(jsObject({
      'map': _map,
      'path': _toJsCoords(p.coords),
      'strokeColor': _hex(color).toJS,
      'strokeWeight': width.toJS,
      'strokeOpacity': 1.0.toJS,
      'strokeLineCap': 'round'.toJS,
      'strokeLineJoin': 'round'.toJS,
    }));
    _overlays.add(_Tracked(() => line.setMap(null), null));
  }

  void _addPolyline(NPolylineOverlay p) {
    final line = JsPolyline(jsObject({
      'map': _map,
      'path': _toJsCoords(p.coords),
      'strokeColor': _hex(p.color ?? AppColors.primaryScale[400]!).toJS,
      'strokeWeight': (p.width ?? 4).round().toJS,
      'strokeOpacity': 1.0.toJS,
    }));
    _overlays.add(_Tracked(() => line.setMap(null), null));
  }

  void _addPolygon(NPolygonOverlay poly) {
    final rings = <JSArray<JsLatLng>>[_toJsCoords(poly.coords)];
    for (final hole in poly.holes ?? const <List<NLatLng>>[]) {
      rings.add(_toJsCoords(hole));
    }
    final fill = poly.color ?? const Color(0x1A723AFF);
    final polygon = JsPolygon(jsObject({
      'map': _map,
      'paths': rings.toJS,
      'fillColor': _hex(fill).toJS,
      'fillOpacity': _opacity(fill).toJS,
      'strokeColor':
          _hex(poly.outlineColor ?? AppColors.primaryScale[400]!).toJS,
      'strokeWeight': (poly.outlineWidth ?? 2).round().toJS,
      'strokeOpacity': 0.9.toJS,
    }));
    _overlays
        .add(_Tracked(() => polygon.setMap(null), NOverlayType.polygonOverlay));
  }
}

JsMap _createJsMap(web.HTMLElement host, NaverMapViewOptions options) {
  final cam = options.initialCameraPosition;
  final center = cam != null
      ? JsLatLng(cam.target.latitude, cam.target.longitude)
      : JsLatLng(36.0, 127.5);
  final zoom = cam?.zoom.round() ?? 7;
  return JsMap(
    host,
    jsObject({
      'center': center,
      'zoom': zoom.toJS,
      'draggable': options.scrollGesturesEnable.toJS,
      'pinchZoom': options.zoomGesturesEnable.toJS,
      'scrollWheel': options.zoomGesturesEnable.toJS,
      'disableDoubleClickZoom': (!options.zoomGesturesEnable).toJS,
      'zoomControl': false.toJS,
      'mapDataControl': false.toJS,
      'scaleControl': false.toJS,
      'mapTypeControl': false.toJS,
      'logoControl': true.toJS,
    }),
  );
}

JSArray<JsLatLng> _toJsCoords(List<NLatLng> coords) =>
    [for (final c in coords) JsLatLng(c.latitude, c.longitude)].toJS;

/// Derives the 1-based stop number from a marker id like `stop_0` → `1`.
String _labelFromId(String id) {
  final match = RegExp(r'(\d+)$').firstMatch(id);
  if (match == null) return '';
  final n = int.tryParse(match.group(1)!);
  return n == null ? '' : '${n + 1}';
}

/// Reproduces trip_created_screen's `_buildNumberMarker` as an HTML badge.
String _markerHtml(String label) {
  final border = _hex(AppColors.primaryScale[400]!);
  final text = _hex(AppColors.primaryScale[500]!);
  return '<div style="width:36px;height:36px;border-radius:50%;'
      'background:#ffffff;border:2px solid $border;'
      'box-shadow:0 2px 4px rgba(32,31,33,0.15);'
      'display:flex;align-items:center;justify-content:center;'
      'font-weight:700;font-size:14px;color:$text;'
      'font-family:sans-serif;">$label</div>';
}

String _hex(Color c) {
  final argb = c.toARGB32();
  return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}

double _opacity(Color c) => ((c.toARGB32() >> 24) & 0xFF) / 255.0;

class _Tracked {
  _Tracked(this.remove, this.type);
  final void Function() remove;
  final NOverlayType? type;
}
