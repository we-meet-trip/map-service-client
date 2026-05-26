import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

const _kErrorColor = AppColors.error;

class AppTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? hintText;
  final String? labelText;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const AppTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.labelText,
    this.errorText,
    this.onChanged,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()
      ..addListener(() {
        setState(() => _isFocused = _focusNode.hasFocus);
      });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.labelText != null) ...[
              Text(
                widget.labelText!,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppColors.neutralScale[500],
                ),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onChanged: widget.onChanged,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.neutralScale[600],
              ),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  color: AppColors.neutralScale[300],
                ),
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                suffixIcon: ListenableBuilder(
                  listenable: widget.controller,
                  builder: (context, _) => widget.controller.text.isEmpty
                      ? const SizedBox.shrink()
                      : GestureDetector(
                          onTap: () {
                            widget.controller.clear();
                            widget.onChanged?.call('');
                          },
                          child: Icon(
                            AppIcons.cancel,
                            size: 18,
                            color: AppColors.neutralScale[300],
                          ),
                        ),
                ),
                // Flutter 기본 밑줄은 숨기고 아래에서 직접 그림
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
            // 밑줄 영역
            Stack(
              children: [
                // 기본 회색 선
                Container(
                  height: 1,
                  color: hasError
                      ? _kErrorColor
                      : AppColors.neutralScale[200],
                ),
                // 포커스 시 확장되는 보라색 선
                if (!hasError)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    height: 1.5,
                    width: _isFocused ? constraints.maxWidth : 0,
                    color: AppColors.secondaryScale[900],
                  ),
              ],
            ),
            if (hasError) ...[
              const SizedBox(height: 6),
              Text(
                widget.errorText!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _kErrorColor,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
