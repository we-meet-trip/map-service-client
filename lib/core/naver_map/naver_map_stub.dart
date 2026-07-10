// Web stub for flutter_naver_map
// ignore_for_file: avoid_unused_constructor_parameters

import 'package:flutter/material.dart';

class FlutterNaverMap {
  Future<void> init({
    required String clientId,
    Function(dynamic)? onAuthFailed,
  }) async {}
}

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

class NCameraPosition {
  final NLatLng target;
  final double zoom;
  const NCameraPosition({required this.target, this.zoom = 14});
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

class NaverMapController {
  Future<void> addOverlay(dynamic overlay) async {}
  Future<void> addOverlayAll(Iterable<dynamic> overlays) async {}
  Future<void> updateCamera(NCameraUpdate update) async {}
  Future<void> clearOverlays({NOverlayType? type}) async {}
}

class NCameraUpdate {
  static NCameraUpdate fitBounds(NLatLngBounds bounds, {EdgeInsets? padding}) =>
      NCameraUpdate._();
  static NCameraUpdate fromCameraPosition(NCameraPosition position) =>
      NCameraUpdate._();
  static NCameraUpdate zoomIn() => NCameraUpdate._();
  static NCameraUpdate zoomOut() => NCameraUpdate._();
  NCameraUpdate._();
  NCameraUpdate setAnimation({NCameraAnimation? animation, Duration? duration}) =>
      this;
}

class NCameraAnimation {
  static const NCameraAnimation fly = NCameraAnimation._();
  static const NCameraAnimation easing = NCameraAnimation._();
  const NCameraAnimation._();
}

class NOverlayImage {
  static Future<NOverlayImage> fromWidget({
    required Widget widget,
    required Size size,
    required BuildContext context,
  }) async =>
      NOverlayImage._();
  NOverlayImage._();
}

class NMarker {
  const NMarker({
    required String id,
    required NLatLng position,
    NOverlayImage? icon,
  });
}

class NPolylineOverlay {
  const NPolylineOverlay({
    required String id,
    required List<NLatLng> coords,
    Color? color,
    double? width,
  });
}

class NPathOverlay {
  const NPathOverlay({
    required String id,
    required List<NLatLng> coords,
    Color? color,
    double? width,
    Color? outlineColor,
    double? outlineWidth,
  });
}

class NPolygonOverlay {
  const NPolygonOverlay({
    required String id,
    required List<NLatLng> coords,
    List<List<NLatLng>>? holes,
    Color? color,
    Color? outlineColor,
    double? outlineWidth,
  });
}

class NOverlayType {
  static const NOverlayType polygonOverlay = NOverlayType._();
  const NOverlayType._();
}

class NaverMap extends StatelessWidget {
  final NaverMapViewOptions options;
  final void Function(NaverMapController)? onMapReady;

  const NaverMap({super.key, required this.options, this.onMapReady});

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
