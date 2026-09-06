import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/api/api_client.dart';
import 'package:map_service_client/core/api/kakao_login_flow.dart';

Matcher failsWith(String code) =>
    throwsA(isA<ApiException>().having((error) => error.code, 'code', code));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'accepts only the matching callback host, path and state once',
    () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      final pending = harness.flow.run('state');
      await harness.launched.future;
      for (final link in [
        'other://kakao?state=state&code=wrong',
        'mapauth://other?state=state&code=wrong',
        'mapauth://kakao/other?state=state&code=wrong',
        'mapauth://kakao?state=other&code=wrong',
      ]) {
        harness.links.add(Uri.parse(link));
      }
      expect(harness.codes, isEmpty);
      harness.complete('accepted');
      harness.complete('duplicate');
      await pending;
      expect(harness.codes, ['accepted']);
      expect(harness.cancelled, 1);
      expect(harness.links.hasListener, isFalse);
    },
  );

  test('subscribes before opening the browser', () async {
    late _Harness harness;
    harness = _Harness(
      launch: (_) async {
        expect(harness.links.hasListener, isTrue);
        harness.complete('immediate');
        return true;
      },
    );
    addTearDown(harness.dispose);
    await harness.flow.run('state');
    expect(harness.codes, ['immediate']);
  });

  test('failed launch cancels callback timer and subscription', () async {
    late _Harness harness;
    harness = _Harness(
      timeout: const Duration(milliseconds: 10),
      launch: (_) async {
        harness.links.add(
          Uri.parse('mapauth://kakao?state=state&error=denied'),
        );
        return false;
      },
    );
    await expectLater(
      harness.flow.run('state'),
      failsWith('BROWSER_UNAVAILABLE'),
    );
    expect(harness.cancelled, 1);
    expect(harness.links.hasListener, isFalse);
    expect(harness.codes, isEmpty);
    await harness.dispose();
  });

  test('throwing launcher cancels the callback timer too', () async {
    final harness = _Harness(
      launch: (_) async => throw StateError('native failure'),
      timeout: const Duration(milliseconds: 10),
    );
    await expectLater(
      harness.flow.run('state'),
      failsWith('BROWSER_UNAVAILABLE'),
    );
    expect(harness.cancelled, 1);
    await harness.dispose();
  });

  test('callback timeout closes the subscription', () async {
    final harness = _Harness(timeout: const Duration(milliseconds: 10));
    final checked = expectLater(
      harness.flow.run('state'),
      failsWith('KAKAO_TIMEOUT'),
    );
    await checked;
    expect(harness.cancelled, 1);
    expect(harness.codes, isEmpty);
    await harness.dispose();
  });

  test('a browser launcher that never finishes also times out', () async {
    final harness = _Harness(
      launch: (_) => Completer<bool>().future,
      timeout: const Duration(milliseconds: 10),
    );
    final checked = expectLater(
      harness.flow.run('state'),
      failsWith('KAKAO_TIMEOUT'),
    );
    await checked;
    expect(harness.cancelled, 1);
    await harness.dispose();
  });

  test(
    'link stream error is handled without leaking its native message',
    () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      final checked = expectLater(
        harness.flow.run('state'),
        failsWith('KAKAO_CALLBACK_UNAVAILABLE'),
      );
      await harness.launched.future;
      harness.links.addError(StateError('private native error'));
      await checked;
      expect(harness.cancelled, 1);
    },
  );

  test(
    'provider cancellation is a stable error and does not exchange a code',
    () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      final checked = expectLater(
        harness.flow.run('state'),
        failsWith('KAKAO_CANCELLED'),
      );
      await harness.launched.future;
      harness.links.add(
        Uri.parse('mapauth://kakao?state=state&error=access_denied'),
      );
      await checked;
      expect(harness.codes, isEmpty);
      expect(harness.cancelled, 1);
    },
  );

  test(
    'session changed during authorization prevents opening a browser',
    () async {
      final authorized = Completer<String>();
      final harness = _Harness(authorizeUrl: (_) => authorized.future);
      addTearDown(harness.dispose);
      final checked = expectLater(
        harness.flow.run('state'),
        failsWith('SESSION_CHANGED'),
      );
      harness.version++;
      authorized.complete('https://kauth.kakao.com/oauth/authorize');
      await checked;
      expect(harness.launched.isCompleted, isFalse);
      expect(harness.links.hasListener, isFalse);
    },
  );

  for (final changed in ['account', 'environment']) {
    test('$changed change while waiting rejects a stale callback', () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      final checked = expectLater(
        harness.flow.run('state'),
        failsWith('SESSION_CHANGED'),
      );
      await harness.launched.future;
      if (changed == 'account') {
        harness.version++;
      } else {
        harness.scope = 'prod';
      }
      harness.complete('stale');
      await checked;
      expect(harness.codes, isEmpty);
      expect(harness.cancelled, 1);
    });
  }

  test(
    'a concurrent attempt cannot consume the first attempt callback',
    () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      final first = harness.flow.run('state');
      await harness.launched.future;
      await expectLater(
        harness.flow.run('other'),
        failsWith('KAKAO_IN_PROGRESS'),
      );
      harness.complete('first');
      await first;
      expect(harness.codes, ['first']);
    },
  );

  test('a failed attempt releases the flow for retry', () async {
    var launches = 0;
    late _Harness harness;
    harness = _Harness(
      launch: (_) async {
        if (++launches == 1) return false;
        harness.complete('retried');
        return true;
      },
    );
    addTearDown(harness.dispose);
    await expectLater(
      harness.flow.run('state'),
      failsWith('BROWSER_UNAVAILABLE'),
    );
    await harness.flow.run('state');
    expect(harness.codes, ['retried']);
    expect(harness.cancelled, 2);
  });
}

class _Harness {
  _Harness({
    Future<String> Function(String)? authorizeUrl,
    Future<bool> Function(Uri)? launch,
    Duration timeout = const Duration(minutes: 3),
  }) {
    links = StreamController<Uri>.broadcast(
      sync: true,
      onCancel: () => cancelled++,
    );
    flow = KakaoLoginFlow(
      authorizeUrl:
          authorizeUrl ??
          (_) async => 'https://kauth.kakao.com/oauth/authorize',
      launch: (uri) {
        if (!launched.isCompleted) launched.complete();
        return launch?.call(uri) ?? Future.value(true);
      },
      callbacks: () => links.stream,
      exchange: (code) async => codes.add(code),
      sessionVersion: () => version,
      storageScope: () => scope,
      callbackTimer: (duration, callback) => timer = Timer(duration, callback),
      timeout: timeout,
    );
  }

  late final StreamController<Uri> links;
  late final KakaoLoginFlow flow;
  final launched = Completer<void>();
  final codes = <String>[];
  int cancelled = 0;
  Timer? timer;
  int version = 1;
  String scope = 'test';

  void complete(String code) {
    links.add(Uri.parse('mapauth://kakao?state=state&code=$code'));
  }

  Future<void> dispose() {
    expect(
      timer?.isActive ?? false,
      isFalse,
      reason: 'callback timer must be cancelled',
    );
    return links.close();
  }
}
