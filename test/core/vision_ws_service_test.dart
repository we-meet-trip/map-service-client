import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/state/auth_store.dart';
import 'package:map_service_client/core/state/service_consent_store.dart';
import 'package:map_service_client/features/vision/models/vision_models.dart';
import 'package:map_service_client/features/vision/services/vision_ws_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class TestSink implements WebSocketSink {
  final sent = <String>[];
  bool closed = false;
  @override
  void add(dynamic data) => sent.add(data as String);
  @override
  Future<void> close([int? code, String? reason]) async => closed = true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestChannel implements WebSocketChannel {
  final StreamController<dynamic> incoming;
  TestChannel({bool ready = true, this.closedCode, bool sync = false})
    : incoming = StreamController<dynamic>(sync: sync) {
    if (ready) connected.complete();
  }
  final connected = Completer<void>();
  final int? closedCode;
  @override
  int? get closeCode => closedCode;
  @override
  final TestSink sink = TestSink();
  @override
  Stream<dynamic> get stream => incoming.stream;
  @override
  Future<void> get ready => connected.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final auth = AuthStore.instance;
  const request = VisionRequest(
    sessionId: 'request-1',
    frameB64: '',
    voiceText: '설명',
  );
  late VisionWsService service;
  late List<TestChannel> channels;
  late List<String> errors;
  late List<VisionResponse> responses;
  late List<String> protocols;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
    await auth.save(
      const AuthTokens(accessToken: 'token-a', refreshToken: 'ra', userId: 1),
    );
    final consent = ServiceConsentStore.instance;
    consent.loadStatus = () async => ServiceConsentStatus.fromJson({
      'terms_version': servicePolicyVersion,
      'privacy_version': servicePrivacyVersion,
      'minimum_age': 18,
      'accepted': true,
      'age_eligible': true,
      'accepted_at': '2026-09-07T00:00:00Z',
    });
    await consent.refresh();
    channels = [];
    errors = [];
    responses = [];
    protocols = [];
    service = VisionWsService(
      responseTimeout: const Duration(milliseconds: 20),
      channelFactory: (uri, offered) {
        expect(uri.query, isEmpty);
        protocols = offered.toList();
        final channel = TestChannel();
        channels.add(channel);
        return channel;
      },
    );
    service.errors.listen(errors.add);
    service.responses.listen(responses.add);
  });

  tearDown(() async {
    service.dispose();
    for (final channel in channels) {
      await channel.incoming.close();
    }
  });

  test(
    'bearer travels in subprotocol and only matching request completes',
    () async {
      await service.sendFrame(request);
      expect(protocols, ['map.vision.v1', 'bearer.token-a']);
      expect(
        jsonDecode(channels.single.sink.sent.single)['session_id'],
        'request-1',
      );
      channels.single.incoming.add(
        '{"session_id":"old-request","status":"done"}',
      );
      await Future<void>.delayed(Duration.zero);
      expect(responses, isEmpty);
      channels.single.incoming.add(
        '{"session_id":"request-1","status":"done"}',
      );
      await Future<void>.delayed(Duration.zero);
      expect(responses.single.sessionId, 'request-1');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(errors, isEmpty);
    },
  );

  test('timeout closes the socket and permits the next request', () async {
    await service.sendFrame(request);
    await Future<void>.delayed(const Duration(milliseconds: 35));
    expect(errors, hasLength(1));
    expect(channels.first.sink.closed, isTrue);
    await service.sendFrame(request);
    expect(channels, hasLength(2));
    expect(channels.last.sink.sent, hasLength(1));
  });

  test('server close releases processing and next send reconnects', () async {
    await service.sendFrame(request);
    await channels.first.incoming.close();
    await Future<void>.delayed(Duration.zero);
    expect(errors, hasLength(1));
    await service.sendFrame(request);
    expect(channels, hasLength(2));
  });

  test('a new account cannot receive the old account response', () async {
    await service.sendFrame(request);
    await auth.save(
      const AuthTokens(accessToken: 'token-b', refreshToken: 'rb', userId: 2),
    );
    channels.first.incoming.add('{"session_id":"request-1","status":"done"}');
    await Future<void>.delayed(Duration.zero);
    expect(responses, isEmpty);
    await service.sendFrame(request);
    expect(channels.first.sink.closed, isTrue);
    expect(channels, hasLength(1));
    expect(ServiceConsentStore.instance.canAccess, isFalse);
    await ServiceConsentStore.instance.refresh();
    await service.sendFrame(request);
    expect(protocols.last, 'bearer.token-b');
  });

  test('logged out requests never create a socket', () async {
    await auth.clear();
    await service.sendFrame(request);
    await Future<void>.delayed(Duration.zero);
    expect(channels, isEmpty);
    expect(errors, isNotEmpty);
  });

  test(
    'structured policy denial invalidates consent before displaying a result',
    () async {
      await service.sendFrame(request);
      channels.single.incoming.add(
        '{"session_id":"request-1","status":"failed","code":"AGE_RESTRICTED","error":"blocked"}',
      );
      await Future<void>.delayed(Duration.zero);
      expect(ServiceConsentStore.instance.canAccess, isFalse);
      expect(responses, isEmpty);
      expect(channels.single.sink.closed, isTrue);
      await service.sendFrame(request);
      expect(channels.single.sink.sent, hasLength(1));
    },
  );

  test(
    'opaque failed handshake rechecks policy once and queued retry sends no frame',
    () async {
      service.dispose();
      final channel = TestChannel(ready: false);
      channels.add(channel);
      var connections = 0;
      service = VisionWsService(
        channelFactory: (_, _) {
          connections++;
          return channel;
        },
      );
      final checked = Completer<ServiceConsentStatus>();
      var checks = 0;
      ServiceConsentStore.instance.loadStatus = () {
        checks++;
        return checked.future;
      };
      final sending = service.sendFrame(request);
      await Future<void>.delayed(Duration.zero);
      channel.connected.completeError(StateError('opaque handshake failure'));
      await Future<void>.delayed(Duration.zero);
      final retry = service.sendFrame(request);
      expect(checks, 1);
      expect(connections, 1);
      checked.complete(
        ServiceConsentStatus.fromJson({
          'terms_version': servicePolicyVersion,
          'privacy_version': servicePrivacyVersion,
          'minimum_age': 18,
          'accepted': false,
          'age_eligible': false,
          'accepted_at': null,
        }),
      );
      await Future.wait([sending, retry]);
      expect(ServiceConsentStore.instance.canAccess, isFalse);
      expect(channel.sink.sent, isEmpty);
      expect(connections, 1);
    },
  );

  test(
    'queued retry cannot send an old request after the account changes during policy recheck',
    () async {
      service.dispose();
      final channel = TestChannel(ready: false);
      channels.add(channel);
      var connections = 0;
      service = VisionWsService(
        channelFactory: (_, _) {
          connections++;
          return channel;
        },
      );
      final store = ServiceConsentStore.instance;
      final receipt = store.status!;
      final checking = Completer<ServiceConsentStatus>();
      store.loadStatus = () => checking.future;
      final sending = service.sendFrame(request);
      await Future<void>.delayed(Duration.zero);
      channel.connected.completeError(StateError('opaque handshake failure'));
      await Future<void>.delayed(Duration.zero);
      final retry = service.sendFrame(request);
      await auth.save(
        const AuthTokens(accessToken: 'token-b', refreshToken: 'rb', userId: 2),
      );
      store.loadStatus = () async => receipt;
      await store.refresh();
      expect(store.canAccess, isTrue);
      checking.complete(receipt);
      await Future.wait([sending, retry]);
      expect(connections, 1);
      expect(channel.sink.sent, isEmpty);
    },
  );

  test('close 4403 without a JSON frame also rechecks server policy', () async {
    service.dispose();
    final channel = TestChannel(closedCode: 4403);
    channels.add(channel);
    service = VisionWsService(channelFactory: (_, _) => channel);
    await service.sendFrame(request);
    var checks = 0;
    ServiceConsentStore.instance.loadStatus = () async {
      checks++;
      return ServiceConsentStatus.fromJson({
        'terms_version': servicePolicyVersion,
        'privacy_version': servicePrivacyVersion,
        'minimum_age': 18,
        'accepted': false,
        'age_eligible': null,
        'accepted_at': null,
      });
    };
    await channel.incoming.close();
    await Future<void>.delayed(Duration.zero);
    expect(checks, 1);
    expect(ServiceConsentStore.instance.canAccess, isFalse);
  });

  test(
    'refused external AI permission sends no frame and opens no socket',
    () async {
      await service.sendFrame(request, canSend: () => false);
      expect(channels, isEmpty);
    },
  );

  test('consent withdrawn while connection waits sends no frame', () async {
    service.dispose();
    var allowed = true;
    final channel = TestChannel(ready: false);
    channels.add(channel);
    service = VisionWsService(channelFactory: (_, _) => channel);
    final pending = service.sendFrame(request, canSend: () => allowed);
    await Future<void>.delayed(Duration.zero);
    allowed = false;
    channel.connected.complete();
    await pending;
    expect(channel.sink.sent, isEmpty);
  });

  test(
    'withdrawn permission discards an already-sent response and closes socket',
    () async {
      var allowed = true;
      await service.sendFrame(request, canSend: () => allowed);
      expect(channels.single.sink.sent, hasLength(1));
      allowed = false;
      channels.single.incoming.add(
        '{"session_id":"request-1","status":"done"}',
      );
      await Future<void>.delayed(Duration.zero);
      expect(responses, isEmpty);
      expect(channels.single.sink.closed, isTrue);
      expect(errors.single, contains('동의가 철회'));
      await service.sendFrame(request, canSend: () => allowed);
      expect(channels, hasLength(1));
    },
  );

  test(
    'revocation after parsing but before subscriber delivery discards queued result',
    () async {
      service.dispose();
      final channel = TestChannel(sync: true);
      channels.add(channel);
      service = VisionWsService(channelFactory: (_, _) => channel);
      service.responses.listen(responses.add);
      var generation = 0;
      await service.sendFrame(request, canSend: () => generation == 0);
      // Synchronous input parses and queues an asynchronous broadcast event.
      channel.incoming.add('{"session_id":"request-1","status":"done"}');
      generation++;
      await Future<void>.delayed(Duration.zero);
      expect(responses, isEmpty);
      // A new grant can authorize a new request without reviving the old one.
      await service.sendFrame(request, canSend: () => generation == 1);
      channel.incoming.add('{"session_id":"request-1","status":"done"}');
      await Future<void>.delayed(Duration.zero);
      expect(responses, hasLength(1));
    },
  );

  test(
    'account change during connection cannot send the previous account request',
    () async {
      service.dispose();
      final channel = TestChannel(ready: false);
      channels.add(channel);
      service = VisionWsService(channelFactory: (_, _) => channel);
      final pending = service.sendFrame(request);
      await Future<void>.delayed(Duration.zero);
      await auth.save(
        const AuthTokens(accessToken: 'token-b', refreshToken: 'rb', userId: 2),
      );
      channel.connected.complete();
      await pending;
      expect(channel.sink.sent, isEmpty);
    },
  );
}
