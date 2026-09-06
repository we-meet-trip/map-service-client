import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as g;

class MapCoordinate {
  final double latitude;
  final double longitude;
  const MapCoordinate(this.latitude, this.longitude);
}

class MapCoordinateBounds {
  final MapCoordinate southWest;
  final MapCoordinate northEast;
  const MapCoordinateBounds({required this.southWest, required this.northEast});
}

class MapPoint {
  final double x;
  final double y;
  const MapPoint(this.x, this.y);
  static const MapPoint relativeCenter = MapPoint(0.5, 0.5);
}

class MapCameraPosition {
  final MapCoordinate target;
  final double zoom;
  final double bearing;
  final double tilt;
  const MapCameraPosition({
    required this.target,
    this.zoom = 14,
    this.bearing = 0,
    this.tilt = 0,
  });
}

class AppMapType {
  static const AppMapType basic = AppMapType._();
  const AppMapType._();
}

class AppMapOptions {
  final MapCameraPosition? initialCameraPosition;
  final bool scrollGesturesEnable;
  final bool zoomGesturesEnable;
  final bool rotationGesturesEnable;
  final AppMapType mapType;
  final EdgeInsets contentPadding;
  const AppMapOptions({
    this.initialCameraPosition,
    this.scrollGesturesEnable = true,
    this.zoomGesturesEnable = true,
    this.rotationGesturesEnable = true,
    this.mapType = const AppMapType._(),
    this.contentPadding = EdgeInsets.zero,
  });
}

abstract class MapLocationOverlay {
  Future<void> setIsVisible(bool isVisible);
  Future<void> setPosition(MapCoordinate position);
  Future<void> setBearing(double bearing);
}

enum MapCameraUpdateKind { fitBounds, fromPosition, zoomIn, zoomOut }

class MapCameraUpdate {
  final MapCameraUpdateKind kind;
  final MapCoordinateBounds? bounds;
  final EdgeInsets? padding;
  final MapCameraPosition? position;
  MapCameraAnimation? animation;
  Duration? duration;

  MapCameraUpdate._(this.kind, {this.bounds, this.padding, this.position});

  static MapCameraUpdate fitBounds(
    MapCoordinateBounds bounds, {
    EdgeInsets? padding,
  }) => MapCameraUpdate._(
    MapCameraUpdateKind.fitBounds,
    bounds: bounds,
    padding: padding,
  );
  static MapCameraUpdate fromCameraPosition(MapCameraPosition position) =>
      MapCameraUpdate._(MapCameraUpdateKind.fromPosition, position: position);
  static MapCameraUpdate scrollAndZoomTo({
    MapCoordinate? target,
    double? zoom,
  }) => MapCameraUpdate._(
    MapCameraUpdateKind.fromPosition,
    position: MapCameraPosition(
      target: target ?? const MapCoordinate(0, 0),
      zoom: zoom ?? 15,
    ),
  );
  static MapCameraUpdate zoomIn() =>
      MapCameraUpdate._(MapCameraUpdateKind.zoomIn);
  static MapCameraUpdate zoomOut() =>
      MapCameraUpdate._(MapCameraUpdateKind.zoomOut);

  MapCameraUpdate setAnimation({
    MapCameraAnimation? animation,
    Duration? duration,
  }) {
    this.animation = animation;
    this.duration = duration;
    return this;
  }
}

enum MapCameraAnimation { fly, easing, none }

enum MapCameraUpdateReason { developer, gesture }

class MapOverlayImage {
  final g.BitmapDescriptor bitmap;
  const MapOverlayImage(this.bitmap);

  static Future<MapOverlayImage> fromWidget({
    required Widget widget,
    required Size size,
    required BuildContext context,
  }) async {
    final key = GlobalKey();
    final overlay = Overlay.of(context);
    final ratio = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -size.width * 2,
        top: 0,
        child: RepaintBoundary(
          key: key,
          child: Material(
            type: MaterialType.transparency,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: widget,
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('Map marker is no longer mounted');
      final image = await boundary.toImage(pixelRatio: ratio);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) {
          throw StateError('Map marker image could not be encoded');
        }
        return MapOverlayImage(
          g.BitmapDescriptor.bytes(
            data.buffer.asUint8List(),
            imagePixelRatio: ratio,
            width: size.width,
            height: size.height,
          ),
        );
      } finally {
        image.dispose();
      }
    } finally {
      entry.remove();
      entry.dispose();
    }
  }
}

class MapMarker {
  final String id;
  MapCoordinate _position;
  final MapOverlayImage? icon;
  final MapPoint? anchor;
  final Size? size;
  final bool flat;
  double _angle;
  bool _isVisible;
  void Function(MapMarker overlay)? onTap;

  MapMarker({
    required this.id,
    required MapCoordinate position,
    this.icon,
    this.anchor,
    this.size,
    this.flat = false,
    double angle = 0,
  }) : _position = position,
       _angle = angle,
       _isVisible = true;

  /// 지도에 올린 뒤 값이 바뀌었음을 알리는 통로.
  ///
  /// 방향과 표시 여부는 마커를 올린 뒤에도 계속 바뀐다 — 길안내 화면은 기기가
  /// 향한 쪽이 바뀔 때마다 각도를 다시 준다. 올릴 때 한 번만 읽으면 그 뒤
  /// 변화가 화면에 닿지 않아, 방향 표시가 처음 각도에 멈춘 채로 남는다.
  /// 지도를 그리는 쪽이 여기에 자기 갱신을 걸어 둔다.
  void Function()? onChanged;

  /// 지금 자리. 지도에 마커를 올릴 때 읽는다.
  MapCoordinate get position => _position;

  /// 지금 방향(도). 0 이 위쪽이다.
  double get angle => _angle;

  /// 지금 표시 여부.
  bool get isVisible => _isVisible;

  void setOnTapListener(void Function(MapMarker overlay) listener) {
    onTap = listener;
  }

  void setPosition(MapCoordinate position) {
    _position = position;
    onChanged?.call();
  }

  void setIsVisible(bool isVisible) {
    _isVisible = isVisible;
    onChanged?.call();
  }

  void setAngle(double angle) {
    _angle = angle;
    onChanged?.call();
  }
}

enum MapOverlayType {
  marker,
  polygonOverlay,
  polylineOverlay,
  pathOverlay,
}

class MapPolylineOverlay {
  final String id;
  final List<MapCoordinate> coords;
  final Color? color;
  final double? width;
  const MapPolylineOverlay({
    required this.id,
    required this.coords,
    this.color,
    this.width,
  });
}

class MapPathOverlay {
  final String id;
  final List<MapCoordinate> coords;
  final Color? color;
  final double? width;
  final Color? outlineColor;
  final double? outlineWidth;
  const MapPathOverlay({
    required this.id,
    required this.coords,
    this.color,
    this.width,
    this.outlineColor,
    this.outlineWidth,
  });
}

class MapPolygonOverlay {
  final String id;
  final List<MapCoordinate> coords;
  final List<List<MapCoordinate>>? holes;
  final Color? color;
  final Color? outlineColor;
  final double? outlineWidth;
  const MapPolygonOverlay({
    required this.id,
    required this.coords,
    this.holes,
    this.color,
    this.outlineColor,
    this.outlineWidth,
  });
}
