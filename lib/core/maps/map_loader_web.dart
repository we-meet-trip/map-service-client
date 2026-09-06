import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

@JS('__mapGoogleReady')
external set _readyCallback(JSFunction callback);
@JS('gm_authFailure')
external set _authFailureCallback(JSFunction callback);

Future<bool> loadMaps(
  String key, {
  required void Function() onAuthFailure,
}) async {
  final ready = Completer<bool>();
  _readyCallback = (() {
    if (!ready.isCompleted) ready.complete(true);
  }).toJS;
  _authFailureCallback = (() {
    onAuthFailure();
    if (!ready.isCompleted) ready.complete(false);
  }).toJS;
  final script = web.HTMLScriptElement()
    ..id = 'map-google-sdk'
    ..async = true
    ..src = Uri.https('maps.googleapis.com', '/maps/api/js', {
      'key': key,
      'callback': '__mapGoogleReady',
      'loading': 'async',
      'libraries': 'marker',
      'language': 'ko',
      'region': 'KR',
    }).toString();
  final errors = script.onError.listen((_) {
    if (!ready.isCompleted) ready.complete(false);
  });
  web.document.head!.append(script);
  try {
    return await ready.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => false,
    );
  } finally {
    await errors.cancel();
  }
}
