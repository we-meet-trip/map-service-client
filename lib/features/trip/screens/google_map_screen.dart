import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../common/theme/app_colors.dart';
import '../../../core/api/trip_api_service.dart';

class GoogleMapScreen extends StatefulWidget {
  const GoogleMapScreen({
    super.key,
    this.stops = const [],
    this.showBackButton = false,
  });

  final List<TripStop> stops;
  final bool showBackButton;

  @override
  State<GoogleMapScreen> createState() => _GoogleMapScreenState();
}

class _GoogleMapScreenState extends State<GoogleMapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = const {};
  Set<Polyline> _polylines = const {};

  late final List<_Stop> _displayStops;

  static const _placeholder = [
    _Stop(
      name: '속초 버스 터미널',
      address: '강원특별자치도 속초시 중앙로 96',
      time: '09:00',
      position: LatLng(38.2052, 128.5917),
    ),
    _Stop(
      name: '속초해변',
      address: '강원특별자치도 속초시 청호동',
      time: '09:12',
      position: LatLng(38.2014, 128.6008),
    ),
    _Stop(
      name: '속초 중앙시장',
      address: '강원특별자치도 속초시 중앙로 147',
      time: '09:25',
      position: LatLng(38.2089, 128.5875),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _displayStops = widget.stops.isNotEmpty
        ? widget.stops
            .map((s) => _Stop(
                  name: s.name,
                  address: s.address,
                  time: s.time,
                  position: LatLng(s.latitude, s.longitude),
                  path: s.transportToNext?.path
                      ?.map((p) => LatLng(p[0], p[1]))
                      .toList(),
                ))
            .toList()
        : _placeholder;
    _buildOverlays();
  }

  Future<void> _buildOverlays() async {
    final markers = <Marker>{};
    final routeCoords = <LatLng>[];

    for (int i = 0; i < _displayStops.length; i++) {
      final icon = await _makeNumberedMarker(i + 1);
      if (!mounted) return;
      markers.add(Marker(
        markerId: MarkerId('stop_$i'),
        position: _displayStops[i].position,
        icon: icon,
        infoWindow: InfoWindow(
          title: _displayStops[i].name,
          snippet: '${_displayStops[i].time} · ${_displayStops[i].address}',
        ),
      ));
    }

    for (int i = 0; i < _displayStops.length - 1; i++) {
      final leg = _displayStops[i].path;
      final seg = (leg != null && leg.length >= 2)
          ? leg
          : [_displayStops[i].position, _displayStops[i + 1].position];
      for (final p in seg) {
        if (routeCoords.isEmpty ||
            routeCoords.last.latitude != p.latitude ||
            routeCoords.last.longitude != p.longitude) {
          routeCoords.add(p);
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _markers = markers;
      _polylines = routeCoords.length >= 2
          ? {
              Polyline(
                polylineId: const PolylineId('route'),
                points: routeCoords,
                color: AppColors.primaryScale[400]!,
                width: 5,
              ),
            }
          : const {};
    });
  }

  Future<BitmapDescriptor> _makeNumberedMarker(int number) async {
    const size = 72.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawCircle(
      const Offset(size / 2, size / 2 + 2),
      size / 2 - 4,
      Paint()
        ..color = Colors.black.withAlpha(0x26)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 4,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 4,
      Paint()
        ..color = AppColors.primaryScale[400]!
        ..strokeWidth = 4.0
        ..style = PaintingStyle.stroke,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryScale[500],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));

    final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _fitBounds();
  }

  void _fitBounds() {
    if (_displayStops.isEmpty) return;
    final lats = _displayStops.map((s) => s.position.latitude);
    final lngs = _displayStops.map((s) => s.position.longitude);
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(lats.reduce(min), lngs.reduce(min)),
          northeast: LatLng(lats.reduce(max), lngs.reduce(max)),
        ),
        56.0,
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialTarget = _displayStops.isNotEmpty
        ? _displayStops.first.position
        : const LatLng(37.5665, 126.9780);

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: initialTarget, zoom: 14),
            markers: _markers,
            polylines: _polylines,
            onMapCreated: _onMapCreated,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          if (widget.showBackButton)
            Positioned(
              top: 12,
              left: 12,
              child: SafeArea(
                bottom: false,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.neutralScale[600]!.withAlpha(0x1A),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: AppColors.neutralScale[600],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stop {
  final String name;
  final String address;
  final String time;
  final LatLng position;
  final List<LatLng>? path;

  const _Stop({
    required this.name,
    required this.address,
    required this.time,
    required this.position,
    this.path,
  });
}
