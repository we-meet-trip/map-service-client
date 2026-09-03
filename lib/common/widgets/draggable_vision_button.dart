import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';

class DraggableVisionButton extends StatefulWidget {
  const DraggableVisionButton({super.key});

  @override
  State<DraggableVisionButton> createState() => _DraggableVisionButtonState();
}

class _DraggableVisionButtonState extends State<DraggableVisionButton> {
  static const double _size = 56;
  static const double _margin = 16;

  Offset _position = const Offset(double.infinity, 300);
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final screenWidth = MediaQuery.of(context).size.width;
      _position = Offset(screenWidth - _size - _margin, 300);
      _initialized = true;
    }
  }

  void _onDragEnd(DraggableDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // 부모 Stack 기준으로 좌표 변환
    final stackBox =
        context.findAncestorRenderObjectOfType<RenderStack>();
    if (stackBox == null) return;

    final local = stackBox.globalToLocal(details.offset);
    double x = local.dx;
    double y = local.dy;

    // 화면 경계 내로 클램프
    x = x.clamp(_margin, screenWidth - _size - _margin);
    y = y.clamp(_margin, screenHeight - _size - _margin * 4);

    // 좌우 중 가까운 쪽으로 스냅
    final mid = screenWidth / 2;
    x = x < mid ? _margin : screenWidth - _size - _margin;

    setState(() => _position = Offset(x, y));
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: Draggable(
        feedback: _buildButton(dragging: true),
        childWhenDragging: const SizedBox.shrink(),
        onDragEnd: _onDragEnd,
        child: _buildButton(),
      ),
    );
  }

  Widget _buildButton({bool dragging = false}) {
    return GestureDetector(
      onTap: dragging ? null : () => context.push('/vision'),
      child: Material(
        elevation: dragging ? 12 : 6,
        shape: const CircleBorder(),
        color: Colors.transparent,
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                AppColors.primaryScale[400]!,
                AppColors.primaryScale[600]!,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryScale[500]!.withValues(alpha: 0.45),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.camera_alt_rounded,
              color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
