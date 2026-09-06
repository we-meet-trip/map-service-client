import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as g;
import 'package:map_service_client/core/maps/map_adapter.dart';
import 'package:map_service_client/core/maps/map_bootstrap.dart';

void main() {
  test(
    'platform keys remain separate and missing keys never use a server fallback',
    () {
      expect(
        resolveGoogleMapsKey(
          MapPlatformKind.android,
          androidKey: ' android-client ',
          iosKey: 'ios-client',
          webKey: 'web-client',
        ),
        'android-client',
      );
      expect(
        resolveGoogleMapsKey(
          MapPlatformKind.ios,
          androidKey: 'android-client',
          iosKey: 'ios-client',
          webKey: 'web-client',
        ),
        'ios-client',
      );
      expect(
        resolveGoogleMapsKey(
          MapPlatformKind.web,
          androidKey: 'android-client',
          iosKey: 'ios-client',
          webKey: '',
        ),
        isEmpty,
      );
      expect(
        resolveGoogleMapsKey(MapPlatformKind.web, webKey: 'replace-client-key'),
        isEmpty,
      );
    },
  );

  test(
    'markers propagate position, bearing, visibility and tap events to Google objects',
    () {
      final store = MapOverlayStore();
      addTearDown(store.dispose);
      var taps = 0;
      var changes = 0;
      store.addListener(() => changes++);
      final marker = MapMarker(
        id: 'place',
        position: const MapCoordinate(37, 127),
        flat: true,
      );
      marker.setOnTapListener((_) => taps++);
      store.add(marker);
      expect(store.markers.single.flat, isTrue);
      marker.setPosition(const MapCoordinate(38, 128));
      marker.setAngle(90);
      marker.setIsVisible(false);
      final actual = store.markers.single;
      expect(actual.position, const g.LatLng(38, 128));
      expect(actual.rotation, 90);
      expect(actual.visible, isFalse);
      actual.onTap!();
      expect(taps, 1);
      expect(changes, 4);
      store.clear();
      marker.setPosition(const MapCoordinate(36, 126));
      expect(changes, 5); // Detached markers must not mutate a disposed view.
    },
  );

  test(
    'route geometry and outline are preserved without inventing coordinates',
    () {
      final store = MapOverlayStore();
      addTearDown(store.dispose);
      store.add(
        const MapPathOverlay(
          id: 'walk',
          coords: [MapCoordinate(37, 127), MapCoordinate(37.01, 127.02)],
          color: Colors.blue,
          width: 6,
          outlineColor: Colors.white,
          outlineWidth: 2,
        ),
      );
      expect(store.polylines, hasLength(2));
      expect(
        store.polylines.singleWhere((p) => p.polylineId.value == 'walk').points,
        [const g.LatLng(37, 127), const g.LatLng(37.01, 127.02)],
      );
      expect(
        store.polylines
            .singleWhere((p) => p.polylineId.value.endsWith(':outline'))
            .width,
        10,
      );
    },
  );

  test('polygon holes survive and clearing polygons retains markers', () {
    final store = MapOverlayStore();
    addTearDown(store.dispose);
    store.add(MapMarker(id: 'place', position: const MapCoordinate(37, 127)));
    store.add(
      const MapPolygonOverlay(
        id: 'region',
        coords: [
          MapCoordinate(37, 127),
          MapCoordinate(38, 127),
          MapCoordinate(38, 128),
        ],
        holes: [
          [
            MapCoordinate(37.2, 127.2),
            MapCoordinate(37.3, 127.2),
            MapCoordinate(37.3, 127.3),
          ],
        ],
      ),
    );
    expect(store.polygons.single.holes.single, hasLength(3));
    store.clear(type: MapOverlayType.polygonOverlay);
    expect(store.polygons, isEmpty);
    expect(store.markers, hasLength(1));
  });

  test(
    'zero-area bounds become a camera target instead of invalid SDK bounds',
    () {
      final update = googleCameraUpdate(
        MapCameraUpdate.fitBounds(
          const MapCoordinateBounds(
            southWest: MapCoordinate(37, 127),
            northEast: MapCoordinate(37, 127),
          ),
        ),
      );
      expect((update.toJson() as List).first, 'newLatLngZoom');
    },
  );

  testWidgets(
    'missing SDK configuration shows an error instead of fake map tiles',
    (tester) async {
      mapsReady.value = false;
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 300,
            height: 300,
            child: AppMap(options: AppMapOptions()),
          ),
        ),
      );
      expect(find.textContaining('지도를 불러올 수 없습니다'), findsOneWidget);
      expect(find.byType(g.GoogleMap), findsNothing);
    },
  );

  testWidgets('marker widgets become actual PNG bitmap descriptors', (
    tester,
  ) async {
    Future<MapOverlayImage>? pending;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                pending = MapOverlayImage.fromWidget(
                  context: context,
                  size: const Size(24, 24),
                  widget: const ColoredBox(color: Colors.red),
                );
              },
              child: const Text('capture'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('capture'));
    await tester.pump();
    final result = await tester.runAsync(() => pending!);
    expect(result!.bitmap, isA<g.BytesMapBitmap>());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
