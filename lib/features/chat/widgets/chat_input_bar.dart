import 'dart:math';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../common/theme/app_colors.dart';

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({super.key, required this.onSend});
  final ValueChanged<String> onSend;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();

  static const _capsuleHeight = 56.0;
  static const _buttonDiameter = 40.0;
  static const _buttonMargin = 8.0;

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: SizedBox(
          height: _capsuleHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: _capsuleHeight,
                padding: const EdgeInsets.only(
                  left: 24,
                  right: _buttonDiameter + _buttonMargin * 2 + 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.inputBarBg,
                  borderRadius: BorderRadius.circular(_capsuleHeight / 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.centerLeft,
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: '메시지를 입력하세요',
                    hintStyle: TextStyle(fontSize: 14, color: Color(0xFFB0B0BC)),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              Positioned(
                right: _buttonMargin,
                child: GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: _buttonDiameter,
                    height: _buttonDiameter,
                    decoration: const BoxDecoration(
                      color: AppColors.myBubbleBg,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Transform.rotate(
                        angle: -25 * pi / 180,
                        child: const PhosphorIcon(
                          PhosphorIconsRegular.paperPlaneTilt,
                          size: 22,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
