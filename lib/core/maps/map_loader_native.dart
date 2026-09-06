// Native API keys are initialized by AndroidManifest/AppDelegate from the same
// platform-specific dart-define used by map_bootstrap.dart.
Future<bool> loadMaps(
  String key, {
  required void Function() onAuthFailure,
}) async => key.isNotEmpty;
