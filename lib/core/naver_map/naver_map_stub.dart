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

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'web/naver_loader.dart';
import 'web/naver_web_controller.dart';

export 'web/naver_web_controller.dart' show NaverMapController;

// ── SDK init ──────────────────────────────────────────────────────────────────

class FlutterNaverMap {
  Future<void> init({
    required String clientId,
    Function(dynamic)? onAuthFailed,
  }) async {
    if (clientId.isEmpty) {
      naverLoadFailed.value = true;
      return;
    }
    unawaited(
      loadNaverMaps(
        clientId: clientId,
        onAuthFailed: (e) => onAuthFailed?.call(e),
      ).catchError((Object _) {}),
    );
  }
}

// ── Value types ───────────────────────────────────────────────────────────────

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
      NCameraUpdate._(NCameraUpdateKind.fitBounds, bounds: bounds, padding: padding);
  static NCameraUpdate fromCameraPosition(NCameraPosition position) =>
      NCameraUpdate._(NCameraUpdateKind.fromPosition, position: position);
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

class NOverlayImage {
  const NOverlayImage._();
  static Future<NOverlayImage> fromWidget({
    required Widget widget,
    required Size size,
    required BuildContext context,
  }) async =>
      const NOverlayImage._();
}

class NMarker {
  final String id;
  final NLatLng position;
  final NOverlayImage? icon;
  void Function(NMarker overlay)? onTap;

  NMarker({required this.id, required this.position, this.icon});

  void setOnTapListener(void Function(NMarker overlay) listener) {
    onTap = listener;
  }
}

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

class NPolylineOverlay {
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
}

// ── The map widget (real Naver JS map via a platform view) ───────────────────

class NaverMap extends StatefulWidget {
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
      return;
    }
    final host = _host;
    if (!mounted || host == null) return;
    final controller = NaverMapController.create(host, widget.options);
    widget.onMapReady?.call(controller);
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
