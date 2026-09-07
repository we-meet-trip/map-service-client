import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/config/app_config.dart';
import '../../../core/state/auth_store.dart';
import '../../../core/state/service_consent_store.dart';
import '../models/vision_models.dart';

class _PermittedVisionResponse {
  _PermittedVisionResponse(this.response, this.canDeliver);
  final VisionResponse response;
  final bool Function() canDeliver;
}

class VisionWsService {
  VisionWsService({
    this.responseTimeout = const Duration(seconds: 60),
    WebSocketChannel Function(Uri, Iterable<String>)? channelFactory,
    ServiceConsentStore? consentStore,
  }) : _consent = consentStore ?? ServiceConsentStore.instance,
       _channelFactory =
           channelFactory ??
           ((uri, protocols) =>
               WebSocketChannel.connect(uri, protocols: protocols)) {
    _consent.addListener(_policyChanged);
  }
  final ServiceConsentStore _consent;
  void _policyChanged() {
    if (!_consent.canAccess) disconnect();
  }

  final Duration responseTimeout;
  final WebSocketChannel Function(Uri, Iterable<String>) _channelFactory;
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Future<void>? _connecting;
  Future<void>? _policyRecheck;
  Timer? _timeout;
  String? _pendingId;
  bool Function()? _pendingCanSend;
  int? _sessionVersion;
  bool _disposed = false;
  int _connectionVersion = 0;
  final _responseController =
      StreamController<_PermittedVisionResponse>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  // Broadcast delivery is asynchronous. Keep the original permission until the
  // subscriber receives the event, including revoke-then-regrant races.
  Stream<VisionResponse> get responses => _responseController.stream
      .where((event) => event.canDeliver())
      .map((event) => event.response);
  Stream<String> get errors => _errorController.stream;

  static Uri _endpoint() {
    final base = Uri.parse(kApiBaseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    // 배포본 토큰은 앱의 API origin 밖으로 보내지 않는다.
    final host = kDebugMode
        ? const String.fromEnvironment('VISION_SERVER_HOST')
        : '';
    if (host.isNotEmpty) return Uri.parse('$scheme://$host/ws/vision');
    return base.replace(
      scheme: scheme,
      path: '/ws/vision',
      query: null,
      fragment: null,
    );
  }

  Future<void> connect(String sessionId) async {
    if (_disposed) return;
    final requestSession = AuthStore.instance.sessionVersion;
    if (_policyRecheck case final pending?) await pending;
    if (_disposed || requestSession != AuthStore.instance.sessionVersion) {
      return;
    }
    if (!_consent.canAccess) {
      _error('이용 조건 확인이 필요해요.');
      return;
    }
    if (_sessionVersion != AuthStore.instance.sessionVersion) disconnect();
    if (_channel != null && _connecting == null) return;
    final active = _connecting;
    if (active != null) return active;
    final pending = _connect();
    _connecting = pending;
    try {
      await pending;
    } finally {
      if (identical(_connecting, pending)) _connecting = null;
    }
  }

  Future<void> _connect() async {
    final token = AuthStore.instance.accessToken;
    if (token == null ||
        !AppConfig.instance.requestsAllowed ||
        !_consent.canAccess) {
      _error('로그인 후 다시 시도해주세요.');
      return;
    }
    _sessionVersion = AuthStore.instance.sessionVersion;
    final version = ++_connectionVersion;
    try {
      final channel = _channelFactory(_endpoint(), [
        'map.vision.v1',
        'bearer.$token',
      ]);
      _channel = channel;
      _sub = channel.stream.listen(
        (data) {
          if (_disposed ||
              !_consent.canAccess ||
              version != _connectionVersion ||
              _sessionVersion != AuthStore.instance.sessionVersion) {
            return;
          }
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            final code = json['code'] ?? json['error'];
            if (code is String &&
                ServiceConsentStore.isPolicyDenial(403, code)) {
              _consent.invalidate(reason: code);
              _error('이용 조건을 다시 확인해주세요.');
              return;
            }
            final response = VisionResponse.fromJson(json);
            if (_pendingId == null ||
                (response.sessionId != _pendingId &&
                    response.sessionId != 'unknown')) {
              return;
            }
            if (_pendingCanSend != null && !_pendingCanSend!()) {
              _error('외부 AI 전송 동의가 철회되어 응답을 표시하지 않았어요.');
              disconnect();
              return;
            }
            _timeout?.cancel();
            final permission = _pendingCanSend;
            final session = _sessionVersion;
            _pendingId = null;
            _pendingCanSend = null;
            _responseController.add(
              _PermittedVisionResponse(
                response,
                () =>
                    !_disposed &&
                    version == _connectionVersion &&
                    session == AuthStore.instance.sessionVersion &&
                    _consent.canAccess &&
                    (permission == null || permission()),
              ),
            );
          } catch (_) {
            _error('응답을 읽지 못했어요. 다시 시도해주세요.');
          }
        },
        onError: (Object _) {
          if (version != _connectionVersion) return;
          _refreshPolicyAfterSocketFailure();
          _error('서버에 연결하지 못했어요. 다시 시도해주세요.');
          disconnect();
        },
        onDone: () {
          if (identical(_channel, channel)) {
            if (channel.closeCode == 4403) _refreshPolicyAfterSocketFailure();
            _channel = null;
            _error('연결이 종료됐어요. 다시 시도해주세요.');
          }
        },
      );
      await channel.ready.timeout(const Duration(seconds: 10));
      if (version != _connectionVersion) {
        await channel.sink.close();
        return;
      }
      if (_disposed ||
          !_consent.canAccess ||
          _sessionVersion != AuthStore.instance.sessionVersion) {
        disconnect();
      }
    } catch (_) {
      if (version != _connectionVersion) return;
      _refreshPolicyAfterSocketFailure();
      _error('서버에 연결하지 못했어요. 다시 시도해주세요.');
      disconnect();
    }
  }

  void _refreshPolicyAfterSocketFailure() {
    if (_disposed ||
        _policyRecheck != null ||
        !_consent.canAccess ||
        _sessionVersion != AuthStore.instance.sessionVersion) {
      return;
    }
    // Browsers do not expose the JSON/close code of a refused HTTP handshake.
    // Recheck once through authenticated REST; no inference is retried here.
    late final Future<void> work;
    work = _consent
        .refresh(force: true)
        .catchError((Object _) {
          // The store itself removes any accepted receipt on lookup failure.
        })
        .whenComplete(() {
          if (identical(_policyRecheck, work)) _policyRecheck = null;
        });
    _policyRecheck = work;
  }

  Future<void> sendFrame(
    VisionRequest request, {
    bool Function()? canSend,
  }) async {
    if (_disposed) return;
    final requestSession = AuthStore.instance.sessionVersion;
    if (_policyRecheck case final pending?) await pending;
    if (_disposed || requestSession != AuthStore.instance.sessionVersion) {
      return;
    }
    if (!_consent.canAccess) {
      _error('이용 조건을 확인한 뒤 다시 시도해주세요.');
      return;
    }
    if (canSend != null && !canSend()) {
      _error('외부 AI 전송 동의를 다시 확인해주세요.');
      return;
    }
    if (_sessionVersion != AuthStore.instance.sessionVersion) disconnect();
    if (_connecting != null) await _connecting;
    if (_channel == null) await connect(request.sessionId);
    if (_channel == null ||
        !_consent.canAccess ||
        _sessionVersion != AuthStore.instance.sessionVersion ||
        requestSession != AuthStore.instance.sessionVersion ||
        (canSend != null && !canSend())) {
      _error('로그인과 연결 상태를 확인한 뒤 다시 시도해주세요.');
      return;
    }
    if (_pendingId != null) {
      _error('이전 요청이 처리 중이에요. 다시 시도해주세요.');
      disconnect();
      return;
    }
    _pendingId = request.sessionId;
    _pendingCanSend = canSend;
    _timeout = Timer(responseTimeout, () {
      _error('응답 시간이 초과됐어요. 다시 시도해주세요.');
      disconnect();
    });
    try {
      _channel!.sink.add(jsonEncode(request.toJson()));
    } catch (_) {
      _error('요청을 보내지 못했어요. 다시 시도해주세요.');
      disconnect();
    }
  }

  void _error(String message) {
    _timeout?.cancel();
    _pendingId = null;
    _pendingCanSend = null;
    if (!_disposed) _errorController.add(message);
  }

  void disconnect() {
    _connectionVersion++;
    _connecting = null;
    _timeout?.cancel();
    _pendingId = null;
    _pendingCanSend = null;
    _sub?.cancel();
    _sub = null;
    final old = _channel;
    _channel = null;
    old?.sink.close();
  }

  void dispose() {
    _disposed = true;
    _consent.removeListener(_policyChanged);
    disconnect();
    _responseController.close();
    _errorController.close();
  }
}
