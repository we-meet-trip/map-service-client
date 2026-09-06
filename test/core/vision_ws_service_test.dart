import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/state/auth_store.dart';
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
  final incoming = StreamController<dynamic>();
  final connected = Completer<void>()..complete();
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
    expect(protocols.last, 'bearer.token-b');
  });

  test('logged out requests never create a socket', () async {
    await auth.clear();
    await service.sendFrame(request);
    await Future<void>.delayed(Duration.zero);
    expect(channels, isEmpty);
    expect(errors, isNotEmpty);
  });
}
