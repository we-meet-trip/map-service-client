import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/vision_models.dart';
import '../services/vision_ws_service.dart';
import '../widgets/bbox_overlay.dart';

class _ChatMessage {
  final bool isUser;
  final String text;
  final VisionResponse? response;

  _ChatMessage({required this.isUser, required this.text, this.response});
}

class VisionScreen extends StatefulWidget {
  const VisionScreen({super.key});

  @override
  State<VisionScreen> createState() => _VisionScreenState();
}

class _VisionScreenState extends State<VisionScreen> {
  CameraController? _cameraController;
  CameraDescription? _backCamera;
  CameraDescription? _frontCamera;
  final _wsService = VisionWsService();
  final _stt = SpeechToText();
  StreamSubscription? _responseSub;
  StreamSubscription? _errorSub;

  Position? _currentPosition;
  bool _cameraReady = false;
  bool _sttReady = false;
  bool _isListening = false;
  bool _isProcessing = false;
  bool _voiceMode = true;
  String? _frozenFrameB64;
  VisionResponse? _lastResult;
  String _confirmedText = '';     // 이전 STT 세션에서 확정된 텍스트
  String _currentSessionText = ''; // 현재 STT 세션 텍스트
  final _partialTextNotifier = ValueNotifier<String>(''); // 화면 표시용 (confirmed + current)
  String _latestWords = '';       // 중지 시 전송할 최종 텍스트

  final List<_ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initStt();
    _initLocation();
    _wsService.connect('vision_${DateTime.now().millisecondsSinceEpoch}');
    _responseSub = _wsService.responses.listen(_onResponse);
    _errorSub = _wsService.errors.listen(_onError);
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    // cameras.first 는 기기별로 전면이 0번일 수 있어 후면을 명시적으로 찾는다.
    _backCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final frontMatches =
        cameras.where((c) => c.lensDirection == CameraLensDirection.front);
    _frontCamera = frontMatches.isEmpty ? null : frontMatches.first;
    _cameraController = CameraController(
      _backCamera!,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _cameraController!.initialize();
    if (mounted) setState(() => _cameraReady = true);
  }

  Future<void> _switchCamera() async {
    final current = _cameraController?.description;
    if (current == null) return;
    final target = current.lensDirection == CameraLensDirection.back
        ? _frontCamera
        : _backCamera;
    if (target == null) return;
    setState(() => _cameraReady = false);
    await _cameraController!.dispose();
    _cameraController = CameraController(
      target,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _cameraController!.initialize();
    if (mounted) setState(() => _cameraReady = true);
  }

  Future<void> _initLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) setState(() => _currentPosition = pos);
    } catch (_) {}
  }

  Future<void> _initStt() async {
    // 음성 인식이 없는 환경이 있다. 그런 곳에서는 준비 단계가 실패를 던지는데,
    // 그대로 두면 카메라까지 함께 못 쓰게 된다. 마이크만 꺼진 채로 화면이
    // 열리게 한다(아래 입력 버튼이 _sttReady 를 보고 스스로 비활성된다).
    var available = false;
    try {
      available = await _stt.initialize(onStatus: _onSttStatus);
    } catch (_) {
      available = false;
    }
    if (mounted) setState(() => _sttReady = available);
  }

  // STT가 플랫폼 한계로 자동 종료되면 이전 텍스트 보존 후 재시작
  void _onSttStatus(String status) {
    if (!mounted) return;
    if ((status == 'done' || status == 'notListening') && _isListening) {
      // 현재 세션 텍스트를 확정 텍스트에 누적
      if (_currentSessionText.isNotEmpty) {
        _confirmedText = _confirmedText.isEmpty
            ? _currentSessionText
            : '$_confirmedText $_currentSessionText';
        _currentSessionText = '';
      }
      _stt.listen(
        onResult: _onSttResult,
        listenOptions: SpeechListenOptions(
          localeId: 'ko_KR',
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 30),
        ),
      );
    }
  }

  void _onSttResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    _currentSessionText = result.recognizedWords;
    final full = _confirmedText.isEmpty
        ? _currentSessionText
        : '$_confirmedText $_currentSessionText';
    _partialTextNotifier.value = full;
    _latestWords = full;
  }

  void _onResponse(VisionResponse response) {
    if (!mounted) return;
    final identify = response.identifyResult;
    final text = identify != null
        ? '${identify.name}\n${identify.description}'
        : (response.error ?? '인식하지 못했어요.');
    setState(() {
      _isProcessing = false;
      _lastResult = response;
      _messages.add(_ChatMessage(isUser: false, text: text, response: response));
    });
  }

  void _onError(String msg) {
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _messages.add(_ChatMessage(isUser: false, text: '오류: $msg'));
    });
  }

  Future<void> _startListening() async {
    if (!_sttReady || _isListening || _isProcessing) return;
    _confirmedText = '';
    _currentSessionText = '';
    _partialTextNotifier.value = '';
    _latestWords = '';
    setState(() {
      _isListening = true;
    });
    await _stt.listen(
      onResult: _onSttResult,
      listenOptions: SpeechListenOptions(
        localeId: 'ko_KR',
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 30),
      ),
    );
  }

  Future<void> _stopListening() async {
    await _stt.stop();
    if (!mounted) return;
    final words = _latestWords.trim();
    if (words.isNotEmpty) {
      // 음성 모드 + 아직 인식된 물체 없음 → 이미지 분석
      // 음성 모드 + 이미 인식된 물체 있음 → 텍스트+컨텍스트만
      // 채팅 모드 → 항상 텍스트만
      if (_voiceMode && _lastResult == null) {
        await _sendWithImage(words);
      } else {
        await _sendTextOnly(words);
      }
    } else {
      _partialTextNotifier.value = '';
      setState(() {
        _isListening = false;
      });
    }
  }

  // 음성 모드: 스크린샷 + 이미지 분석
  Future<void> _sendWithImage(String words) async {
    if (_cameraController == null) return;
    final file = await _cameraController!.takePicture();
    final bytes = await file.readAsBytes();
    final b64 = base64Encode(bytes);

    _partialTextNotifier.value = '';
    setState(() {
      _isListening = false;
      _isProcessing = true;
      _frozenFrameB64 = b64;
      _lastResult = null;
      _messages.add(_ChatMessage(isUser: true, text: words));
    });

    _wsService.sendFrame(VisionRequest(
      sessionId: 'vision_${DateTime.now().millisecondsSinceEpoch}',
      frameB64: b64,
      voiceTriggered: true,
      voiceText: words,
      location: _currentPosition != null
          ? VisionLocation(
              lat: _currentPosition!.latitude,
              lng: _currentPosition!.longitude,
            )
          : null,
    ));
  }

  // 텍스트만 전송 (채팅 모드 또는 첫 인식 이후 후속 대화)
  Future<void> _sendTextOnly(String words) async {
    final priorContext = _lastResult?.identifyResult != null
        ? '${_lastResult!.identifyResult!.name}: ${_lastResult!.identifyResult!.description}'
        : null;

    final history = _messages
        .map((m) => {
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.text,
            })
        .toList();

    _partialTextNotifier.value = '';
    setState(() {
      _isListening = false;
      _isProcessing = true;
      _messages.add(_ChatMessage(isUser: true, text: words));
    });

    _wsService.sendFrame(VisionRequest(
      sessionId: 'vision_${DateTime.now().millisecondsSinceEpoch}',
      frameB64: '',
      voiceTriggered: false,
      voiceText: words,
      priorContext: priorContext,
      conversationHistory: history,
      location: _currentPosition != null
          ? VisionLocation(
              lat: _currentPosition!.latitude,
              lng: _currentPosition!.longitude,
            )
          : null,
    ));
  }

  void _reset() {
    setState(() {
      _frozenFrameB64 = null;
      _lastResult = null;
      _isProcessing = false;
    });
  }

  @override
  void dispose() {
    _responseSub?.cancel();
    _errorSub?.cancel();
    _wsService.dispose();
    _cameraController?.dispose();
    _stt.stop();
    _partialTextNotifier.dispose();
    super.dispose();
  }

  // ───────────────────────────── build ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraArea(),
          if (_lastResult?.detectedObject != null && _frozenFrameB64 != null)
            BboxOverlay(
              bbox: _lastResult!.detectedObject!.bbox,
              label: _lastResult!.identifyResult?.name ??
                  _lastResult!.detectedObject!.label,
            ),
          _buildTopBar(),
          _buildDraggableSheet(),
        ],
      ),
    );
  }

  Widget _buildCameraArea() {
    if (_frozenFrameB64 != null) {
      return Image.memory(base64Decode(_frozenFrameB64!), fit: BoxFit.cover);
    }
    if (!_cameraReady || _cameraController == null) {
      return const ColoredBox(color: Colors.black);
    }
    return CameraPreview(_cameraController!);
  }

  // ───────────────────────── top bar ───────────────────────────────

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _circleButton(
                  child: const Icon(Icons.chevron_left,
                      color: Colors.white, size: 22),
                  onTap: () => context.pop(),
                ),
                Expanded(child: Center(child: _modeToggle())),
                _circleButton(
                  child: const Icon(Icons.cameraswitch,
                      color: Colors.white, size: 18),
                  onTap: _switchCamera,
                ),
              ],
            ),
            if (_lastResult?.identifyResult != null) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD83C5A).withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '빨간 박스를 바탕으로 판단되었어요',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _circleButton({required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.16),
        ),
        child: child,
      ),
    );
  }

  Widget _modeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeBtn('음성', _voiceMode, () => setState(() => _voiceMode = true)),
          _modeBtn('채팅', !_voiceMode, () => setState(() => _voiceMode = false)),
        ],
      ),
    );
  }

  Widget _modeBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: active
              ? const LinearGradient(
                  colors: [Color(0xFFc85f8f), Color(0xFF8b5fb0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFF8c3c78).withValues(alpha: 0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  // ───────────────────── draggable bottom sheet ─────────────────────

  Widget _buildDraggableSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.32,
      minChildSize: 0.14,
      maxChildSize: 0.75,
      snap: true,
      snapSizes: const [0.14, 0.32, 0.75],
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              color: const Color(0xFF3C3A42).withValues(alpha: 0.72),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                children: [
                  // grabber
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // 대화 버블들
                  ..._messages.asMap().entries.map(
                        (e) => KeyedSubtree(
                          key: ValueKey('msg_${e.key}'),
                          child: _buildBubble(e.value),
                        ),
                      ),

                  // 처리 중
                  if (_isProcessing)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _assistantBubble('', loading: true),
                      ),
                    ),

                  // 실시간 STT 텍스트
                  ValueListenableBuilder<String>(
                    valueListenable: _partialTextNotifier,
                    builder: (context, partialText, _) {
                      if (!_isListening || partialText.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 240),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              partialText,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 14),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // 퀵 리플라이
                  if (_lastResult != null && !_isProcessing)
                    _buildQuickReplies(),

                  const SizedBox(height: 16),

                  // 마이크
                  _buildMicRow(),

                  // 청취 중 힌트
                  if (_isListening)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Center(
                        child: Text(
                          '말씀하세요... (탭하면 중지)',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBubble(_ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (msg.isUser)
            Container(
              constraints: const BoxConstraints(maxWidth: 240),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF7a7a86),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(6),
                ),
              ),
              child: Text(msg.text,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, height: 1.5)),
            )
          else
            _assistantBubble(msg.text),
        ],
      ),
    );
  }

  Widget _assistantBubble(String text, {bool loading = false}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 240),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFc85f8f), Color(0xFF8b5fb0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(6),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 48,
                  height: 18,
                  child: _DotsIndicator(),
                )
              : Text(text,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, height: 1.5)),
        ),
        const Positioned(
          left: -4,
          top: -12,
          child: Text('✦',
              style:
                  TextStyle(color: Color(0xFFff8ab8), fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildQuickReplies() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          _quickReplyBtn('다시 찍기', onTap: _reset),
        ],
      ),
    );
  }

  Widget _quickReplyBtn(String label, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _buildMicRow() {
    final bool canListen = _sttReady && !_isProcessing;
    return Center(
      child: GestureDetector(
        onTap: _isListening ? _stopListening : _startListening,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: canListen
                ? const LinearGradient(
                    colors: [Color(0xFFb25fd6), Color(0xFF6a4fd6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: canListen ? null : Colors.white24,
            boxShadow: _isListening
                ? [
                    BoxShadow(
                      color:
                          const Color(0xFF7846c8).withValues(alpha: 0.7),
                      blurRadius: 24,
                      spreadRadius: 4,
                    )
                  ]
                : [
                    BoxShadow(
                      color:
                          const Color(0xFF7846c8).withValues(alpha: 0.5),
                      blurRadius: 18,
                    )
                  ],
          ),
          child: Icon(
            _isListening ? Icons.stop : Icons.mic,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

// ──────────────────── 점 세 개 로딩 애니메이션 ────────────────────

class _DotsIndicator extends StatefulWidget {
  const _DotsIndicator();

  @override
  State<_DotsIndicator> createState() => _DotsIndicatorState();
}

class _DotsIndicatorState extends State<_DotsIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController ctrl;

  @override
  void initState() {
    super.initState();
    ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (ctrl.value * 3 - i).clamp(0.0, 1.0);
            final opacity = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Opacity(
                opacity: opacity.clamp(0.2, 1.0),
                child: const CircleAvatar(
                    radius: 4, backgroundColor: Colors.white),
              ),
            );
          }),
        );
      },
    );
  }
}
