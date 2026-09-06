import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as g;

import 'map_bootstrap.dart';
import 'map_pointer.dart';
import 'map_types.dart';

export 'map_types.dart';

g.LatLng _coordinate(MapCoordinate p) => g.LatLng(p.latitude, p.longitude);
g.CameraPosition _camera(MapCameraPosition p) => g.CameraPosition(
  target: _coordinate(p.target),
  zoom: p.zoom,
  bearing: p.bearing,
  tilt: p.tilt,
);

/// Owns mutable app overlays and translates them to Google SDK objects.
class MapOverlayStore extends ChangeNotifier {
  final Map<String, dynamic> _items = {};

  String _key(dynamic item) => '${item.runtimeType}:${item.id}';

  void add(dynamic item) {
    if (item is! MapMarker &&
        item is! MapPathOverlay &&
        item is! MapPolylineOverlay &&
        item is! MapPolygonOverlay) {
      throw ArgumentError('Unsupported map overlay');
    }
    final old = _items[_key(item)];
    if (old is MapMarker) old.onChanged = null;
    _items[_key(item)] = item;
    if (item is MapMarker) item.onChanged = notifyListeners;
    notifyListeners();
  }

  void clear({MapOverlayType? type}) {
    _items.removeWhere((_, item) {
      final matches =
          type == null ||
          (type == MapOverlayType.marker && item is MapMarker) ||
          (type == MapOverlayType.polygonOverlay &&
              item is MapPolygonOverlay) ||
          (type == MapOverlayType.pathOverlay && item is MapPathOverlay) ||
          (type == MapOverlayType.polylineOverlay &&
              item is MapPolylineOverlay);
      if (matches && item is MapMarker) item.onChanged = null;
      return matches;
    });
    notifyListeners();
  }

  Set<g.Marker> get markers => _items.values
      .whereType<MapMarker>()
      .map(
        (item) => g.Marker(
          markerId: g.MarkerId(item.id),
          position: _coordinate(item.position),
          icon: item.icon?.bitmap ?? g.BitmapDescriptor.defaultMarker,
          anchor: Offset(item.anchor?.x ?? 0.5, item.anchor?.y ?? 1),
          rotation: item.angle,
          visible: item.isVisible,
          flat: item.flat,
          onTap: () => item.onTap?.call(item),
          consumeTapEvents: item.onTap != null,
        ),
      )
      .toSet();

  Set<g.Polyline> get polylines {
    final result = <g.Polyline>{};
    for (final item in _items.values) {
      if (item is MapPathOverlay) {
        final points = item.coords.map(_coordinate).toList();
        final width = (item.width ?? 5).round();
        if ((item.outlineWidth ?? 0) > 0) {
          result.add(
            g.Polyline(
              polylineId: g.PolylineId('${item.id}:outline'),
              points: points,
              color: item.outlineColor ?? Colors.white,
              width: width + (2 * item.outlineWidth!).round(),
              zIndex: 0,
            ),
          );
        }
        result.add(
          g.Polyline(
            polylineId: g.PolylineId(item.id),
            points: points,
            color: item.color ?? Colors.blue,
            width: width,
            zIndex: 1,
          ),
        );
      } else if (item is MapPolylineOverlay) {
        result.add(
          g.Polyline(
            polylineId: g.PolylineId(item.id),
            points: item.coords.map(_coordinate).toList(),
            color: item.color ?? Colors.blue,
            width: (item.width ?? 5).round(),
            zIndex: 1,
          ),
        );
      }
    }
    return result;
  }

  Set<g.Polygon> get polygons => _items.values
      .whereType<MapPolygonOverlay>()
      .map(
        (item) => g.Polygon(
          polygonId: g.PolygonId(item.id),
          points: item.coords.map(_coordinate).toList(),
          holes: (item.holes ?? [])
              .map((ring) => ring.map(_coordinate).toList())
              .toList(),
          fillColor: item.color ?? Colors.transparent,
          strokeColor: item.outlineColor ?? Colors.blue,
          strokeWidth: (item.outlineWidth ?? 1).round(),
          consumeTapEvents: false,
        ),
      )
      .toSet();

  @override
  void dispose() {
    for (final item in _items.values.whereType<MapMarker>()) {
      item.onChanged = null;
    }
    _items.clear();
    super.dispose();
  }
}

g.CameraUpdate googleCameraUpdate(MapCameraUpdate update) {
  switch (update.kind) {
    case MapCameraUpdateKind.fitBounds:
      final bounds = update.bounds!;
      if ((bounds.northEast.latitude - bounds.southWest.latitude).abs() <
              1e-6 &&
          (bounds.northEast.longitude - bounds.southWest.longitude).abs() <
              1e-6) {
        return g.CameraUpdate.newLatLngZoom(_coordinate(bounds.southWest), 15);
      }
      return g.CameraUpdate.newLatLngBounds(
        g.LatLngBounds(
          southwest: _coordinate(bounds.southWest),
          northeast: _coordinate(bounds.northEast),
        ),
        0,
      );
    case MapCameraUpdateKind.fromPosition:
      return g.CameraUpdate.newCameraPosition(_camera(update.position!));
    case MapCameraUpdateKind.zoomIn:
      return g.CameraUpdate.zoomIn();
    case MapCameraUpdateKind.zoomOut:
      return g.CameraUpdate.zoomOut();
  }
}

class AppMapController {
  AppMapController._(this._native, this._state);
  final g.GoogleMapController _native;
  final _AppMapState _state;
  bool _disposed = false;

  Future<void> addOverlay(dynamic overlay) async {
    if (!_disposed) _state._overlays.add(overlay);
  }

  Future<void> addOverlayAll(Iterable<dynamic> overlays) async {
    for (final overlay in overlays) {
      await addOverlay(overlay);
    }
  }

  Future<void> clearOverlays({MapOverlayType? type}) async {
    if (!_disposed) _state._overlays.clear(type: type);
  }

  MapLocationOverlay getLocationOverlay() => _GoogleLocationOverlay(_state);

  Future<MapCameraPosition> getCameraPosition() async {
    final camera = _state._cameraPosition;
    return MapCameraPosition(
      target: MapCoordinate(camera.target.latitude, camera.target.longitude),
      zoom: camera.zoom,
      bearing: camera.bearing,
      tilt: camera.tilt,
    );
  }

  Future<void> updateCamera(MapCameraUpdate update) async {
    if (_disposed) return;
    if (update.padding != null) {
      _state._setPadding(update.padding!);
      await WidgetsBinding.instance.endOfFrame;
    }
    if (_disposed) return;
    _state._programmaticCamera = true;
    final camera = googleCameraUpdate(update);
    if (update.animation == MapCameraAnimation.none) {
      await _native.moveCamera(camera);
    } else {
      await _native.animateCamera(camera, duration: update.duration);
    }
  }

  void _dispose() {
    _disposed = true;
  }
}

class _GoogleLocationOverlay implements MapLocationOverlay {
  _GoogleLocationOverlay(this.state);
  final _AppMapState state;
  @override
  Future<void> setPosition(MapCoordinate position) async {
    if (!state.mounted) return;
    state._changeLocation(position: position);
  }

  @override
  Future<void> setIsVisible(bool isVisible) async {
    if (!state.mounted) return;
    state._changeLocation(visible: isVisible);
  }

  @override
  Future<void> setBearing(double bearing) async {
    if (!state.mounted) return;
    state._changeLocation(bearing: bearing);
  }
}

/// Real Google Maps SDK on Android, iOS and web. No fallback tiles are rendered.
class AppMap extends StatefulWidget {
  const AppMap({
    super.key,
    required this.options,
    this.onMapReady,
    this.onCameraChange,
    this.onMapTapped,
  });
  final AppMapOptions options;
  final void Function(AppMapController)? onMapReady;
  final void Function(MapCameraUpdateReason, bool)? onCameraChange;
  final void Function(MapPoint, MapCoordinate)? onMapTapped;
  @override
  State<AppMap> createState() => _AppMapState();
}

class _AppMapState extends State<AppMap> {
  final _overlays = MapOverlayStore();
  AppMapController? _controller;
  late g.CameraPosition _cameraPosition;
  late EdgeInsets _padding;
  Size _size = Size.zero;
  bool _programmaticCamera = false;
  MapCoordinate? _location;
  bool _locationVisible = false;
  double _locationBearing = 0;

  @override
  void initState() {
    super.initState();
    _cameraPosition = _camera(
      widget.options.initialCameraPosition ??
          const MapCameraPosition(target: MapCoordinate(37.5665, 126.9780)),
    );
    _padding = widget.options.contentPadding;
    _overlays.addListener(_redraw);
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  void _changeLocation({
    MapCoordinate? position,
    bool? visible,
    double? bearing,
  }) {
    if (!mounted) return;
    setState(() {
      if (position != null) _location = position;
      if (visible != null) _locationVisible = visible;
      if (bearing != null) _locationBearing = bearing;
    });
  }

  void _setPadding(EdgeInsets value) {
    // Google SDK padding moves both camera viewport and legal attribution above
    // the app's bottom sheet. Keep a visible viewport on smaller displays.
    final height = math.max(1.0, _size.height);
    final width = math.max(1.0, _size.width);
    setState(
      () => _padding = EdgeInsets.fromLTRB(
        math.min(value.left, width * .2),
        math.min(value.top, height * .2),
        math.min(value.right, width * .2),
        math.min(value.bottom, height * .6),
      ),
    );
  }

  @override
  void dispose() {
    _controller?._dispose();
    _overlays.removeListener(_redraw);
    _overlays.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: mapsReady,
    builder: (context, ready, _) {
      if (!ready) {
        return const ColoredBox(
          color: Color(0xfff3f4f6),
          child: Center(
            child: Text(
              '지도를 불러올 수 없습니다.\n잠시 후 다시 시도해주세요.',
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          _size = constraints.biggest;
          return ValueListenableBuilder<bool>(
            valueListenable: mapPointerEnabled,
            builder: (context, enabled, _) => IgnorePointer(
              ignoring: !enabled,
              child: Listener(
                onPointerDown: (_) => _programmaticCamera = false,
                child: g.GoogleMap(
                  initialCameraPosition: _cameraPosition,
                  mapType: g.MapType.normal,
                  padding: _padding,
                  gestureRecognizers:
                      widget.options.captureScrollGestures && enabled
                      ? {
                          Factory<OneSequenceGestureRecognizer>(
                            EagerGestureRecognizer.new,
                          ),
                        }
                      : const {},
                  scrollGesturesEnabled:
                      widget.options.scrollGesturesEnable && enabled,
                  zoomGesturesEnabled:
                      widget.options.zoomGesturesEnable && enabled,
                  rotateGesturesEnabled:
                      widget.options.rotationGesturesEnable && enabled,
                  tiltGesturesEnabled:
                      widget.options.rotationGesturesEnable && enabled,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  myLocationButtonEnabled: false,
                  webCameraControlEnabled: false,
                  markers: {
                    ..._overlays.markers,
                    if (_locationVisible && _location != null)
                      g.Marker(
                        markerId: const g.MarkerId('__current_location'),
                        position: _coordinate(_location!),
                        rotation: _locationBearing,
                        icon: g.BitmapDescriptor.defaultMarkerWithHue(
                          g.BitmapDescriptor.hueAzure,
                        ),
                      ),
                  },
                  polylines: _overlays.polylines,
                  polygons: _overlays.polygons,
                  onMapCreated: (native) {
                    final controller = AppMapController._(native, this);
                    _controller = controller;
                    widget.onMapReady?.call(controller);
                  },
                  onCameraMove: (position) => _cameraPosition = position,
                  onCameraMoveStarted: () => widget.onCameraChange?.call(
                    _programmaticCamera
                        ? MapCameraUpdateReason.developer
                        : MapCameraUpdateReason.gesture,
                    _programmaticCamera,
                  ),
                  onCameraIdle: () => _programmaticCamera = false,
                  onTap: (position) => widget.onMapTapped?.call(
                    const MapPoint(0, 0),
                    MapCoordinate(position.latitude, position.longitude),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
