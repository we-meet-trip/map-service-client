// Loads the Naver Maps JavaScript API v3 script and exposes readiness/failure
// state to the web map widgets. Web-only (see naver_js.dart header).
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Auth query parameter for the Naver Maps JS v3 script.
///
/// Keys issued in the current NCP console use `ncpKeyId`; legacy keys use
/// `ncpClientId`. If authentication fails with a known-good key, switch this
/// single constant to `ncpClientId`.
const String kNaverAuthParam = 'ncpKeyId';

/// Becomes `true` when the map cannot be shown: no key supplied, the script
/// failed to load, or Naver reported an auth failure (e.g. the deployed domain
/// is not registered as a Web service URL). Map widgets watch this to render a
/// graceful fallback instead of a broken/blank map.
final ValueNotifier<bool> naverLoadFailed = ValueNotifier<bool>(false);

final Completer<void> _ready = Completer<void>();

/// Client ids already injected. A second attempt only makes sense with a key we
/// have not tried yet — re-injecting the same one cannot change the outcome.
final Set<String> _attempted = <String>{};

/// Completes once the Naver Maps script has loaded (before auth is verified).
Future<void> get naverReady => _ready.future;

/// Injects the Naver Maps JS v3 script and wires the global auth-failure hook.
///
/// Calling this again with a *different* client id re-injects the script, which
/// is how the caller retries after an auth failure: the failure verdict only
/// arrives at runtime, so the second key cannot be chosen up front. Repeating a
/// client id already tried is a no-op.
Future<void> loadNaverMaps({
  required String clientId,
  void Function(Object error)? onAuthFailed,
}) {
  if (clientId.isEmpty || _attempted.contains(clientId)) return _ready.future;
  _attempted.add(clientId);

  // A retry starts from a clean slate: the previous attempt set this, and
  // leaving it on would keep the fallback map showing even if this key works.
  naverLoadFailed.value = false;

  // Naver invokes this global function on authentication failure. It must be
  // registered BEFORE the script executes.
  globalContext['navermap_authFailure'] = (() {
    naverLoadFailed.value = true;
    onAuthFailed?.call('navermap_authFailure');
  }).toJS;

  final script = web.HTMLScriptElement()
    ..type = 'text/javascript'
    ..async = true
    ..src =
        'https://oapi.map.naver.com/openapi/v3/maps.js?$kNaverAuthParam=$clientId';
  script.onload = ((web.Event _) {
    if (!_ready.isCompleted) _ready.complete();
  }).toJS;
  script.onerror = ((web.Event _) {
    naverLoadFailed.value = true;
    if (!_ready.isCompleted) {
      _ready.completeError(StateError('naver maps script failed to load'));
    }
  }).toJS;
  web.document.head!.appendChild(script);
  return _ready.future;
}
