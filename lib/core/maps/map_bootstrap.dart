import 'package:flutter/foundation.dart';

import 'map_loader_native.dart'
    if (dart.library.js_interop) 'map_loader_web.dart'
    as platform;

enum MapPlatformKind { android, ios, web, unsupported }

String resolveGoogleMapsKey(
  MapPlatformKind target, {
  String androidKey = const String.fromEnvironment(
    'GOOGLE_MAPS_ANDROID_API_KEY',
  ),
  String iosKey = const String.fromEnvironment('GOOGLE_MAPS_IOS_API_KEY'),
  String webKey = const String.fromEnvironment('GOOGLE_MAPS_WEB_API_KEY'),
}) {
  final key = switch (target) {
    MapPlatformKind.android => androidKey,
    MapPlatformKind.ios => iosKey,
    MapPlatformKind.web => webKey,
    MapPlatformKind.unsupported => '',
  };
  final value = key.trim();
  return value.startsWith('replace-') || value.startsWith('your_') ? '' : value;
}

final ValueNotifier<bool> mapsReady = ValueNotifier(false);
final ValueNotifier<int> mapGeneration = ValueNotifier(0);

Future<void> initializeMaps() async {
  final target = kIsWeb
      ? MapPlatformKind.web
      : switch (defaultTargetPlatform) {
          TargetPlatform.android => MapPlatformKind.android,
          TargetPlatform.iOS => MapPlatformKind.ios,
          _ => MapPlatformKind.unsupported,
        };
  final key = resolveGoogleMapsKey(target);
  if (key.isEmpty) {
    mapsReady.value = false;
    return;
  }
  var authFailed = false;
  final loaded = await platform.loadMaps(
    key,
    onAuthFailure: () {
      authFailed = true;
      mapsReady.value = false;
    },
  );
  mapsReady.value = loaded && !authFailed;
  mapGeneration.value++;
}
