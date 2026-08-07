// Web stub for flutter_naver_map — mirrors flutter_naver_map 1.4.4 API
// ignore_for_file: avoid_unused_constructor_parameters

import 'package:flutter/material.dart';

// ── Init ──────────────────────────────────────────────────────────────────────
class FlutterNaverMap {
  Future<void> init({
    required String clientId,
    Function(dynamic)? onAuthFailed,
  }) async {}
}

// ── Basic types ───────────────────────────────────────────────────────────────
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

class NCameraUpdate {
  static NCameraUpdate fitBounds(NLatLngBounds bounds,
          {EdgeInsets? padding}) =>
      NCameraUpdate._();
  static NCameraUpdate fromCameraPosition(NCameraPosition position) =>
      NCameraUpdate._();
  static NCameraUpdate scrollAndZoomTo({NLatLng? target, double? zoom}) =>
      NCameraUpdate._();
  static NCameraUpdate zoomIn() => NCameraUpdate._();
  static NCameraUpdate zoomOut() => NCameraUpdate._();
  NCameraUpdate._();
  NCameraUpdate setAnimation(
          {NCameraAnimation? animation, Duration? duration}) =>
      this;
}

class NCameraAnimation {
  static const NCameraAnimation fly = NCameraAnimation._();
  static const NCameraAnimation easing = NCameraAnimation._();
  static const NCameraAnimation linear = NCameraAnimation._();
  static const NCameraAnimation none = NCameraAnimation._();
  const NCameraAnimation._();
}

enum NCameraUpdateReason { developer, gesture, control, location }

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
class NOverlayImage {
  static Future<NOverlayImage> fromWidget({
    required Widget widget,
    required Size size,
    required BuildContext context,
  }) async =>
      NOverlayImage._();

  const factory NOverlayImage.fromAssetImage(String assetName) =
      _AssetNOverlayImage;
  NOverlayImage._();
}

class _AssetNOverlayImage implements NOverlayImage {
  final String assetName;
  const _AssetNOverlayImage(this.assetName);
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
}

class NPolygonOverlay {
  final NOverlayInfo info;
  NPolygonOverlay({
    required String id,
    required List<NLatLng> coords,
    List<List<NLatLng>>? holes,
    Color? color,
    Color? outlineColor,
    double? outlineWidth,
  }) : info = NOverlayInfo(type: NOverlayType.polygonOverlay, id: id);
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

// ── NaverMap widget ───────────────────────────────────────────────────────────
class NaverMap extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFE8EAF0),
      child: Center(
        child: Text(
          '지도는 모바일에서 확인하세요',
          style: TextStyle(color: Color(0xFF888888)),
        ),
      ),
    );
  }
}
