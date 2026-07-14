<<<<<<< HEAD
// Web stub for flutter_naver_map — mirrors flutter_naver_map 1.4.4 API
// ignore_for_file: avoid_unused_constructor_parameters
=======
// Web implementation of the flutter_naver_map API surface used by the app.
//
// The adapter (naver_map_adapter.dart) exports THIS file only on web
// (`if (dart.library.io)` selects the real plugin on Android/iOS). Everything
// reachable from here therefore compiles solely for the web target, so it may
// freely use dart:ui_web / dart:js_interop / package:web with no platform
// guards, and the mobile build is untouched.
//
// It renders a real Naver Maps JavaScript API v3 map inside an HtmlElementView
// while keeping the exact public types/constructors that the two map screens
// (trip_created_screen.dart, trip_step5_screen.dart) and main.dart already use,
// so those files need no changes.
import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
>>>>>>> b943c33 (feat: 웹에서 네이버 지도를 실제로 렌더링하는 어댑터 추가)

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'web/naver_loader.dart';
import 'web/naver_web_controller.dart';

export 'web/naver_web_controller.dart' show NaverMapController;

// ── SDK init ─────────────────────────────────────────────────────────────────

// ── Init ──────────────────────────────────────────────────────────────────────
class FlutterNaverMap {
  Future<void> init({
    required String clientId,
    Function(dynamic)? onAuthFailed,
  }) async {
    if (clientId.isEmpty) {
      // No key supplied to the web build → show the graceful fallback rather
      // than attempting (and failing) to load a map.
      naverLoadFailed.value = true;
      return;
    }
    // Kick off script loading but do NOT block app startup on it (main.dart
    // awaits init before runApp). Each NaverMap widget awaits `naverReady`
    // itself before constructing its map.
    unawaited(
      loadNaverMaps(
        clientId: clientId,
        onAuthFailed: (e) => onAuthFailed?.call(e),
      ).catchError((Object _) {
        // A load failure already flips `naverLoadFailed`; swallow here to avoid
        // an unhandled async error.
      }),
    );
  }
}

<<<<<<< HEAD
// ── Basic types ───────────────────────────────────────────────────────────────
=======
// ── Value types (data holders mirroring the plugin's public API) ─────────────

>>>>>>> b943c33 (feat: 웹에서 네이버 지도를 실제로 렌더링하는 어댑터 추가)
class NLatLng {
  final double latitude;
  final double longitude;
  const NLatLng(this.latitude, this.longitude);
}

class NLatLngBounds {
  final NLatLng southWest;
  final NLatLng northEast;
  const NLatLngBounds({required this.southWest, required this.northEast});
}

class NPoint {
  final double x;
  final double y;
  const NPoint(this.x, this.y);
  static const NPoint relativeCenter = NPoint(0.5, 0.5);
}

// ── Camera ────────────────────────────────────────────────────────────────────
class NCameraPosition {
  final NLatLng target;
  final double zoom;
  final double bearing;
  final double tilt;
  const NCameraPosition({
    required this.target,
    this.zoom = 14,
    this.bearing = 0,
    this.tilt = 0,
  });
}

<<<<<<< HEAD
class NCameraUpdate {
  static NCameraUpdate fitBounds(NLatLngBounds bounds,
          {EdgeInsets? padding}) =>
      NCameraUpdate._();
=======
class NMapType {
  static const NMapType basic = NMapType._();
  const NMapType._();
}

class NaverMapViewOptions {
  final NCameraPosition? initialCameraPosition;
  final bool scrollGesturesEnable;
  final bool zoomGesturesEnable;
  final bool rotationGesturesEnable;
  final NMapType mapType;
  const NaverMapViewOptions({
    this.initialCameraPosition,
    this.scrollGesturesEnable = true,
    this.zoomGesturesEnable = true,
    this.rotationGesturesEnable = true,
    this.mapType = const NMapType._(),
  });
}

/// 내 위치 표시 오버레이. 웹 컨트롤러가 실제 마커를 붙이고 이 객체를 통해
/// 표시 여부·위치·방향을 갱신한다.
class NLocationOverlay {
  Future<void> setIsVisible(bool isVisible) async {}
  Future<void> setPosition(NLatLng position) async {}
  Future<void> setBearing(double bearing) async {}
}

enum NCameraUpdateKind { fitBounds, fromPosition, zoomIn, zoomOut }

class NCameraUpdate {
  final NCameraUpdateKind kind;
  final NLatLngBounds? bounds;
  final EdgeInsets? padding;
  final NCameraPosition? position;
  NCameraAnimation? animation;
  Duration? duration;

  NCameraUpdate._(this.kind, {this.bounds, this.padding, this.position});

  static NCameraUpdate fitBounds(NLatLngBounds bounds, {EdgeInsets? padding}) =>
      NCameraUpdate._(NCameraUpdateKind.fitBounds,
          bounds: bounds, padding: padding);
>>>>>>> b943c33 (feat: 웹에서 네이버 지도를 실제로 렌더링하는 어댑터 추가)
  static NCameraUpdate fromCameraPosition(NCameraPosition position) =>
      NCameraUpdate._(NCameraUpdateKind.fromPosition, position: position);

  /// 내비 화면이 현재 위치를 따라갈 때 쓰는 이동. 목표 좌표만 바꾸고 줌은
  /// 주어졌을 때만 반영하도록 카메라 위치로 접어서 넘긴다.
  static NCameraUpdate scrollAndZoomTo({NLatLng? target, double? zoom}) =>
      NCameraUpdate._(
        NCameraUpdateKind.fromPosition,
        position: NCameraPosition(
          target: target ?? const NLatLng(0, 0),
          zoom: zoom ?? 15,
        ),
      );
  static NCameraUpdate zoomIn() => NCameraUpdate._(NCameraUpdateKind.zoomIn);
  static NCameraUpdate zoomOut() => NCameraUpdate._(NCameraUpdateKind.zoomOut);

  NCameraUpdate setAnimation({NCameraAnimation? animation, Duration? duration}) {
    this.animation = animation;
    this.duration = duration;
    return this;
  }
}

class NCameraAnimation {
  static const NCameraAnimation fly = NCameraAnimation._();
  static const NCameraAnimation easing = NCameraAnimation._();
  static const NCameraAnimation linear = NCameraAnimation._();
  static const NCameraAnimation none = NCameraAnimation._();
  const NCameraAnimation._();
}

enum NCameraUpdateReason { developer, gesture, control, location }

<<<<<<< HEAD
// ── Map types ─────────────────────────────────────────────────────────────────
class NMapType {
  static const NMapType basic = NMapType._();
  static const NMapType navi = NMapType._();
  static const NMapType satellite = NMapType._();
  static const NMapType hybrid = NMapType._();
  const NMapType._();
}

class NLogoAlign {
  static const NLogoAlign leftBottom = NLogoAlign._();
  static const NLogoAlign rightBottom = NLogoAlign._();
  static const NLogoAlign leftTop = NLogoAlign._();
  static const NLogoAlign rightTop = NLogoAlign._();
  const NLogoAlign._();
}

class NaverMapViewOptions {
  final NCameraPosition? initialCameraPosition;
  final bool scrollGesturesEnable;
  final bool zoomGesturesEnable;
  final bool rotationGesturesEnable;
  final NMapType mapType;
  final NLogoAlign? logoAlign;
  const NaverMapViewOptions({
    this.initialCameraPosition,
    this.scrollGesturesEnable = true,
    this.zoomGesturesEnable = true,
    this.rotationGesturesEnable = true,
    this.mapType = const NMapType._(),
    this.logoAlign,
  });
}

// ── Overlay image ─────────────────────────────────────────────────────────────
=======
/// On web the marker icon is rendered as an HTML badge by the controller, so
/// this is just an inert token that keeps the screens' `fromWidget` calls valid.
>>>>>>> b943c33 (feat: 웹에서 네이버 지도를 실제로 렌더링하는 어댑터 추가)
class NOverlayImage {
  const NOverlayImage._();
  static Future<NOverlayImage> fromWidget({
    required Widget widget,
    required Size size,
    required BuildContext context,
  }) async =>
<<<<<<< HEAD
      NOverlayImage._();

  const factory NOverlayImage.fromAssetImage(String assetName) =
      _AssetNOverlayImage;
  NOverlayImage._();
}

class _AssetNOverlayImage implements NOverlayImage {
  final String assetName;
  const _AssetNOverlayImage(this.assetName);
=======
      const NOverlayImage._();
}

class NMarker {
  final String id;
  final NLatLng position;
  final NOverlayImage? icon;
  const NMarker({required this.id, required this.position, this.icon});
>>>>>>> b943c33 (feat: 웹에서 네이버 지도를 실제로 렌더링하는 어댑터 추가)
}

// ── Overlay info ──────────────────────────────────────────────────────────────
enum NOverlayType {
  marker,
  infoWindow,
  circleOverlay,
  groundOverlay,
  polygonOverlay,
  polylineOverlay,
  pathOverlay,
  multipartPathOverlay,
  arrowheadPathOverlay,
  locationOverlay,
}

class NOverlayInfo {
  final NOverlayType type;
  final String id;
  const NOverlayInfo({required this.type, required this.id});
}

// ── Location overlay ──────────────────────────────────────────────────────────
class NLocationOverlay {
  void setIsVisible(bool isVisible) {}
  void setPosition(NLatLng position) {}
  void setBearing(double bearing) {}
  void setAnchor(NPoint anchor) {}
  void setIcon(NOverlayImage icon) {}
  void setIconSize(Size size) {}
  void setCircleColor(Color color) {}
  void setCircleRadius(double radius) {}
  void setSubIcon(NOverlayImage? icon) {}
}

// ── Marker caption ────────────────────────────────────────────────────────────
class NOverlayCaption {
  final String text;
  final double textSize;
  final Color? color;
  final Color? haloColor;
  const NOverlayCaption({
    required this.text,
    this.textSize = 14,
    this.color,
    this.haloColor,
  });
  void setOnTapListener(void Function(NMarker marker) listener) {}
}

enum NAlign { center, left, right, top, bottom, topLeft, topRight, bottomLeft, bottomRight }

// ── NMarker ───────────────────────────────────────────────────────────────────
class NMarker {
  final String id;
  final NOverlayInfo info;

  NMarker({
    required this.id,
    required NLatLng position,
    NOverlayImage? icon,
    Color? iconTintColor,
    double alpha = 1.0,
    double angle = 0,
    NPoint anchor = const NPoint(0.5, 1.0),
    Size size = const Size(0, 0),
    NOverlayCaption? caption,
    NOverlayCaption? subCaption,
    List<NAlign> captionAligns = const [NAlign.bottom],
    double captionOffset = 0,
    bool isCaptionPerspectiveEnabled = false,
    bool isIconPerspectiveEnabled = false,
    bool isFlat = false,
    bool isForceShowCaption = false,
    bool isForceShowIcon = false,
    bool isHideCollidedCaptions = false,
    bool isHideCollidedMarkers = false,
    bool isHideCollidedSymbols = false,
    bool isVisible = true,
    int zIndex = 0,
  }) : info = NOverlayInfo(type: NOverlayType.marker, id: id);

  // 메서드 (1.4.4 방식)
  void setPosition(NLatLng value) {}
  void setIcon(NOverlayImage? value) {}
  void setIconTintColor(Color value) {}
  void setAlpha(double value) {}
  void setAngle(double value) {}
  void setAnchor(NPoint value) {}
  void setSize(Size value) {}
  void setCaption(NOverlayCaption? value) {}
  void setSubCaption(NOverlayCaption? value) {}
  void setCaptionAligns(Iterable<NAlign> value) {}
  void setCaptionOffset(double value) {}
  void setIsCaptionPerspectiveEnabled(bool value) {}
  void setIsIconPerspectiveEnabled(bool value) {}
  void setIsFlat(bool value) {}
  void setIsForceShowCaption(bool value) {}
  void setIsForceShowIcon(bool value) {}
  void setIsHideCollidedCaptions(bool value) {}
  void setIsHideCollidedMarkers(bool value) {}
  void setHideCollidedSymbols(bool value) {}
  void setIsVisible(bool value) {}
  void setOnTapListener(Function(NMarker) listener) {}
  void setMap(dynamic map) {}
}

// ── Polyline / Polygon ────────────────────────────────────────────────────────
class NPolylineOverlay {
<<<<<<< HEAD
  final NOverlayInfo info;
  NPolylineOverlay({
    required String id,
    required List<NLatLng> coords,
    Color? color,
    double? width,
  }) : info = NOverlayInfo(type: NOverlayType.polylineOverlay, id: id);

  void setCoords(Iterable<NLatLng> coords) {}
  void setColor(Color color) {}
  void setWidth(double width) {}
  void setIsVisible(bool value) {}
=======
  final String id;
  final List<NLatLng> coords;
  final Color? color;
  final double? width;
  const NPolylineOverlay({
    required this.id,
    required this.coords,
    this.color,
    this.width,
  });
>>>>>>> b943c33 (feat: 웹에서 네이버 지도를 실제로 렌더링하는 어댑터 추가)
}

class NPathOverlay {
  final String id;
  final List<NLatLng> coords;
  final Color? color;
  final double? width;
  final Color? outlineColor;
  final double? outlineWidth;
  const NPathOverlay({
    required this.id,
    required this.coords,
    this.color,
    this.width,
    this.outlineColor,
    this.outlineWidth,
  });
}

class NPolygonOverlay {
<<<<<<< HEAD
  final NOverlayInfo info;
  NPolygonOverlay({
    required String id,
    required List<NLatLng> coords,
    List<List<NLatLng>>? holes,
    Color? color,
    Color? outlineColor,
    double? outlineWidth,
  }) : info = NOverlayInfo(type: NOverlayType.polygonOverlay, id: id);
=======
  final String id;
  final List<NLatLng> coords;
  final List<List<NLatLng>>? holes;
  final Color? color;
  final Color? outlineColor;
  final double? outlineWidth;
  const NPolygonOverlay({
    required this.id,
    required this.coords,
    this.holes,
    this.color,
    this.outlineColor,
    this.outlineWidth,
  });
>>>>>>> b943c33 (feat: 웹에서 네이버 지도를 실제로 렌더링하는 어댑터 추가)
}

// ── Controller ────────────────────────────────────────────────────────────────
class NaverMapController {
  Future<void> addOverlay(dynamic overlay) async {}
  Future<void> addOverlayAll(Iterable<dynamic> overlays) async {}
  Future<void> deleteOverlay(NOverlayInfo info) async {}
  Future<void> updateCamera(NCameraUpdate update) async {}
  Future<void> clearOverlays({NOverlayType? type}) async {}
  Future<NCameraPosition> getCameraPosition() async =>
      const NCameraPosition(target: NLatLng(0, 0));
  NLocationOverlay getLocationOverlay() => NLocationOverlay();
}

<<<<<<< HEAD
// ── NaverMap widget ───────────────────────────────────────────────────────────
class NaverMap extends StatelessWidget {
=======
// ── The map widget (real Naver JS map via a platform view) ───────────────────

class NaverMap extends StatefulWidget {
>>>>>>> b943c33 (feat: 웹에서 네이버 지도를 실제로 렌더링하는 어댑터 추가)
  final NaverMapViewOptions options;
  final void Function(NaverMapController)? onMapReady;
  final void Function(NCameraUpdateReason, bool)? onCameraChange;
  final void Function(NPoint, NLatLng)? onMapTapped;

  const NaverMap({
    super.key,
    required this.options,
    this.onMapReady,
    this.onCameraChange,
    this.onMapTapped,
  });

  @override
  State<NaverMap> createState() => _NaverMapState();
}

class _NaverMapState extends State<NaverMap> {
  static int _seq = 0;
  final String _viewType = 'naver-map-web-${_seq++}';
  web.HTMLDivElement? _host;
  web.ResizeObserver? _resizeObserver;

  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final div = web.HTMLDivElement()
        ..style.width = '100%'
        ..style.height = '100%';
      _host = div;
      return div;
    });
  }

  @override
  void dispose() {
    _resizeObserver?.disconnect();
    super.dispose();
  }

  Future<void> _onPlatformViewCreated(int id) async {
    try {
      await naverReady;
    } catch (_) {
      return; // Fallback is already shown via naverLoadFailed.
    }
    final host = _host;
    if (!mounted || host == null) return;
    final controller = NaverMapController.create(host, widget.options);
    widget.onMapReady?.call(controller);
    // Naver caches the container size at creation; the platform-view div's final
    // width can settle a frame later. Re-measure on any host resize so tiles
    // fill the whole container instead of a stale sub-rect.
    _resizeObserver = web.ResizeObserver(
      ((JSArray<JSAny?> _, web.ResizeObserver _) => controller.refresh()).toJS,
    );
    _resizeObserver!.observe(host);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: naverLoadFailed,
      builder: (context, failed, _) {
        if (failed) return const _MapFallback();
        return HtmlElementView(
          viewType: _viewType,
          onPlatformViewCreated: _onPlatformViewCreated,
        );
      },
    );
  }
}

class _MapFallback extends StatelessWidget {
  const _MapFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFE8EAF0),
      child: Center(
        child: Text(
          '지도를 표시할 수 없습니다',
          style: TextStyle(color: Color(0xFF888888)),
        ),
      ),
    );
  }
}
