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
  _WebLocationOverlay? _locationOverlay;

  /// 화면이 마지막으로 요청한 카메라 의도. 상자 크기 확정 후 재적용용.
  /// 단계 확대·축소는 상대 이동이라 재적용 시 누적됨 → 담지 않는다.
  NCameraUpdate? _lastCamera;

  /// 사용자가 직접 움직였는지. true 면 재적용 중단(화면 빼앗기 방지).
  bool _userMoved = false;

  /// 현재 위치 표시 오버레이. 화면이 여러 번 요청해도 같은 마커를 다룬다.
  NLocationOverlay getLocationOverlay() =>
      _locationOverlay ??= _WebLocationOverlay(_map);

  /// 현재 카메라 상태. 화면이 방위만 되돌릴 때 지금 보고 있는 지점을 유지하려고
  /// 읽어 간다. 웹 지도는 기울기·회전을 쓰지 않아 기본값으로 둔다.
  Future<NCameraPosition> getCameraPosition() async {
    final center = _map.getCenter();
    return NCameraPosition(
      target: NLatLng(center.lat(), center.lng()),
      zoom: _map.getZoom(),
    );
  }

  /// 상자 크기가 정해지거나 바뀐 뒤 호출.
  ///
  /// 지도는 생성 시점의 상자 크기를 기억 → 크기가 한 프레임 뒤 정해지면
  /// 그 전에 잡힌 화면 범위가 어긋난 채 굳는다.
  /// 순서 고정: 크기 통지 → 재그리기 → 굳은 범위 재적용.
  /// 재측정 전에 범위를 넣으면 또 옛 크기 기준으로 계산된다.
  void handleHostResize() {
    naverEventTrigger(_map, 'resize');
    _map.refresh(true);
    if (_userMoved) return;
    final last = _lastCamera;
    if (last != null) _applyCamera(last);
  }

  /// 사용자가 지도를 직접 만졌다고 표시.
  void markUserMoved() => _userMoved = true;

  /// 위젯이 사라질 때 호출. 얹어 둔 것들과 그에 걸린 신호를 정리한다.
  /// 남기면 없어진 마커와 그 마커가 붙들고 있는 화면 상태가 계속 살아남는다.
  void dispose() {
    for (final t in _overlays) {
      t.remove();
    }
    _overlays.clear();
    _locationOverlay = null;
  }

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
      case NCameraUpdateKind.fromPosition:
        _lastCamera = update;
        _applyCamera(update);
      // 아래 둘은 화면의 확대·축소 버튼에서만 옴 = 사용자 의도.
      case NCameraUpdateKind.zoomIn:
        _userMoved = true;
        _map.setZoom(_map.getZoom().round() + 1, true);
      case NCameraUpdateKind.zoomOut:
        _userMoved = true;
        _map.setZoom(_map.getZoom().round() - 1, true);
    }
  }

  void _applyCamera(NCameraUpdate update) {
    switch (update.kind) {
      case NCameraUpdateKind.fitBounds:
        final b = update.bounds!;
        final bounds = JsLatLngBounds(
          JsLatLng(b.southWest.latitude, b.southWest.longitude),
          JsLatLng(b.northEast.latitude, b.northEast.longitude),
        );
        _map.fitBounds(bounds, _marginOf(update.padding));
      case NCameraUpdateKind.fromPosition:
        final p = update.position!;
        _map.morph(
          JsLatLng(p.target.latitude, p.target.longitude),
          p.zoom.round(),
        );
      case NCameraUpdateKind.zoomIn:
      case NCameraUpdateKind.zoomOut:
        break;
    }
  }

  /// 가장자리 여백 — 네 방향 개별 전달.
  /// 숫자 하나면 사방 균일 적용 → 하단 시트에 가리는 화면에서 경로가 숨는다.
  JSAny _marginOf(EdgeInsets? padding) {
    if (padding == null) return 0.0.toJS;
    return jsObject({
      'top': padding.top.toJS,
      'right': padding.right.toJS,
      'bottom': padding.bottom.toJS,
      'left': padding.left.toJS,
    });
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
    JSObject icon() => jsObject({
          'content': _markerHtml(_labelFromId(m.id), m.angle).toJS,
          'anchor': JsPoint(18, 18),
        });

    final marker = JsMarker(jsObject({
      'position': JsLatLng(m.position.latitude, m.position.longitude),
      'map': m.isVisible ? _map : null,
      'icon': icon(),
    }));

    // 올린 뒤에도 바뀌는 값들을 따라간다. 길안내 화면은 기기가 향한 쪽이
    // 바뀔 때마다 각도를 다시 주는데, 올릴 때 한 번만 읽으면 방향 표시가
    // 처음 각도에 멈춘 채로 남는다.
    m.onChanged = () {
      marker.setPosition(JsLatLng(m.position.latitude, m.position.longitude));
      marker.setIcon(icon());
      marker.setMap(m.isVisible ? _map : null);
    };

    // 마커를 눌러 고르는 화면이 있어 클릭을 듣는다. 지도에서 뗄 때 리스너도
    // 함께 떼지 않으면 사라진 마커와 그 마커가 붙들고 있는 화면 상태가
    // 계속 살아남는다.
    final onTap = m.onTap;
    JSAny? listener;
    if (onTap != null) {
      listener = naverEventAddListener(
        marker,
        'click',
        ((JSAny? _) => onTap(m)).toJS,
      );
    }
    _overlays.add(_Tracked(() {
      if (listener != null) {
        naverEventRemoveListener(listener);
      }
      // 뗀 마커가 계속 갱신을 부르면 지도에서 사라진 것이 되살아난다.
      m.onChanged = null;
      marker.setMap(null);
    }, null));
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
      'logoControlOptions': jsObject({
        'position': _logoPosition(options.logoAlign).toJS,
      }),
    }),
  );
}

/// 로고 자리를 JS 지도가 쓰는 이름으로 옮긴다.
///
/// 지도 객체를 만들 때 이름 문자열로 넘긴다 — 위치 상수를 읽으려면 스크립트가
/// 이미 실행돼 있어야 하는데, 이 함수는 그 직전에도 불릴 수 있다.
String _logoPosition(NLogoAlign align) => switch (align) {
      NLogoAlign.leftBottom => 'BOTTOM_LEFT',
      NLogoAlign.rightBottom => 'BOTTOM_RIGHT',
      NLogoAlign.leftTop => 'TOP_LEFT',
      NLogoAlign.rightTop => 'TOP_RIGHT',
    };

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
/// 마커 한 개의 내용. [angle] 은 기기가 향한 쪽(도)이며 0 이 위쪽이다.
///
/// 회전은 내용에 얹는다. 지도 라이브러리가 마커 자체를 돌려 주지 않아,
/// 돌아간 모습이 필요한 마커(길안내의 방향 표시)는 이 자리에서 돌린다.
String _markerHtml(String label, [double angle = 0]) {
  final border = _hex(AppColors.primaryScale[400]!);
  final text = _hex(AppColors.primaryScale[500]!);
  final rotate = angle == 0
      ? ''
      : 'transform:rotate(${angle.toStringAsFixed(1)}deg);';
  return '<div style="width:36px;height:36px;border-radius:50%;'
      'background:#ffffff;border:2px solid $border;'
      'box-shadow:0 2px 4px rgba(32,31,33,0.15);'
      'display:flex;align-items:center;justify-content:center;'
      'font-weight:700;font-size:14px;color:$text;'
      'font-family:sans-serif;$rotate">$label</div>';
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

/// 현재 위치 파란 점. 좌표와 표시 여부가 모두 정해졌을 때만 지도에 올리고,
/// 감춰지면 지도에서 떼어 낸다(오버레이 정리 대상과 섞이지 않도록 별도 관리).
class _WebLocationOverlay extends NLocationOverlay {
  _WebLocationOverlay(this._map);

  final JsMap _map;
  JsMarker? _marker;
  bool _visible = false;
  NLatLng? _position;

  @override
  Future<void> setIsVisible(bool isVisible) async {
    _visible = isVisible;
    _sync();
  }

  @override
  Future<void> setPosition(NLatLng position) async {
    _position = position;
    _sync();
  }

  @override
  Future<void> setBearing(double bearing) async {
    // 방향 표시는 화면이 별도 마커로 그리므로 여기서는 다루지 않는다.
  }

  void _sync() {
    final position = _position;
    if (!_visible || position == null) {
      _marker?.setMap(null);
      return;
    }
    final latLng = JsLatLng(position.latitude, position.longitude);
    final marker = _marker;
    if (marker == null) {
      _marker = JsMarker(jsObject({
        'position': latLng,
        'map': _map,
        'icon': jsObject({
          'content': _locationDotHtml().toJS,
          'anchor': JsPoint(9, 9),
        }),
      }));
      return;
    }
    marker.setPosition(latLng);
    marker.setMap(_map);
  }
}

String _locationDotHtml() {
  final fill = _hex(AppColors.primaryScale[500]!);
  return '<div style="width:18px;height:18px;border-radius:50%;'
      'background:$fill;border:3px solid #ffffff;'
      'box-shadow:0 0 0 1px rgba(32,31,33,0.2);"></div>';
}
