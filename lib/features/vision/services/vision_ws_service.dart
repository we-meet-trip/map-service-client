import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/vision_models.dart';

class VisionWsService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _responseController = StreamController<VisionResponse>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<VisionResponse> get responses => _responseController.stream;
  Stream<String> get errors => _errorController.stream;

  void connect(String sessionId) {
    final host = dotenv.env['VISION_SERVER_HOST'] ?? 'localhost:8000';
    final uri = Uri.parse('ws://$host/ws/vision');
    dev.log('[Vision] connecting to $uri');
    _channel = WebSocketChannel.connect(uri);

    _sub = _channel!.stream.listen(
      (data) {
        dev.log('[Vision] received: $data');
        try {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          _responseController.add(VisionResponse.fromJson(json));
        } catch (e) {
          dev.log('[Vision] parse error: $e');
          _errorController.add('응답 파싱 실패: $e');
        }
      },
      onError: (error) {
        dev.log('[Vision] ws error: $error');
        _errorController.add('연결 오류: $error');
      },
      cancelOnError: false,
    );
  }

  void sendFrame(VisionRequest request) {
    _channel?.sink.add(jsonEncode(request.toJson()));
  }

  void disconnect() {
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _responseController.close();
    _errorController.close();
  }
}
