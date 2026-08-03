import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/config/app_config.dart';
import '../models/vision_models.dart';

class VisionWsService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _responseController = StreamController<VisionResponse>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<VisionResponse> get responses => _responseController.stream;
  Stream<String> get errors => _errorController.stream;

  /// 인식 서버로 이어질 주소.
  ///
  /// 실행 설정에 주소가 적혀 있으면 그것을 쓴다. 개발 중에 인식 서버만 따로
  /// 띄워 붙일 때 쓰는 길이다. 적혀 있지 않으면 앱이 쓰는 서버 주소에서
  /// 파생한다 — 인식 경로는 같은 관문 뒤에 있다.
  ///
  /// 스킴을 서버 주소에서 가져오는 이유: 안전한 연결로 열린 화면에서 평문
  /// 소켓을 열면 브라우저가 그 연결을 막는다. 그렇게 되면 카메라 화면만
  /// 조용히 죽는다.
  static Uri _endpoint() {
    final host = dotenv.env['VISION_SERVER_HOST'] ?? '';
    if (host.isNotEmpty) {
      return Uri.parse('ws://$host/ws/vision');
    }
    final base = Uri.parse(kApiBaseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return base.replace(scheme: scheme, path: '/ws/vision');
  }

  void connect(String sessionId) {
    final uri = _endpoint();
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
