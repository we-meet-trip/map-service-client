import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';

/// 어느 탭에 있든 떠 있는 카메라 인식 버튼.
///
/// 이 위젯은 MainLayout 의 Stack 에 한 번만 놓이고, 그 Stack 은 탭 5개를
/// 전부 덮는다. 그래서 여기 좌표 하나가 앱의 모든 화면에 동시에 적용된다.
/// 기본 위치를 화면 중간에 두면 어느 화면에서든 그 자리의 내용이 가려지고,
/// 달력처럼 촘촘한 화면에서는 아예 누를 수 없는 칸이 생긴다.
class DraggableVisionButton extends StatefulWidget {
  const DraggableVisionButton({super.key});

  @override
  State<DraggableVisionButton> createState() => _DraggableVisionButtonState();
}

class _DraggableVisionButtonState extends State<DraggableVisionButton> {
  static const double _size = 56;
  static const double _margin = 16;

  /// BottomNav 가 쓰는 높이. Stack 은 Scaffold.body 안이라 탭바를 포함하지
  /// 않지만, MediaQuery 의 화면 높이는 포함한다. 그 차이를 여기서 뺀다.
  static const double _bottomNavHeight = 70;

  Offset? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _position ??= _defaultPosition();
  }

  /// 기본 자리는 오른쪽 아래다. 화면 중간은 어느 화면에서든 내용 위다.
  Offset _defaultPosition() {
    final media = MediaQuery.of(context);
    final bottom = media.size.height -
        _bottomNavHeight -
        media.viewPadding.bottom -
        _size -
        _margin;
    return Offset(media.size.width - _size - _margin, bottom);
  }

  void _onDragEnd(DraggableDetails details) {
    final stackBox = context.findAncestorRenderObjectOfType<RenderStack>();
    if (stackBox == null) return;

    // 클램프 기준은 MediaQuery 가 아니라 이 버튼이 실제로 놓인 Stack 이다.
    // 화면 높이를 쓰면 탭바와 홈 인디케이터만큼 아래로 흘러 잘린다.
    final bounds = stackBox.size;
    final media = MediaQuery.of(context);
    final local = stackBox.globalToLocal(details.offset);

    final maxX = bounds.width - _size - _margin;
    final minY = media.viewPadding.top + _margin;
    final maxY = bounds.height - _size - _margin;

    final y = maxY <= minY ? minY : local.dy.clamp(minY, maxY);
    // 좌우 중 가까운 쪽으로 붙인다.
    final x = local.dx < bounds.width / 2 ? _margin : maxX;

    setState(() => _position = Offset(x, y));
  }

  @override
  Widget build(BuildContext context) {
    final position = _position ?? _defaultPosition();
    // 다이얼로그·바텀시트가 떠 있는 동안에는 숨긴다. 모달 위에 떠 있으면
    // 딤 처리를 뚫고 나와 그 아래 내용을 가린다.
    final covered = ModalRoute.of(context)?.isCurrent == false;

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Offstage(
        offstage: covered,
        child: Draggable(
          feedback: _buildButton(dragging: true),
          childWhenDragging: const SizedBox.shrink(),
          onDragEnd: _onDragEnd,
          child: _buildButton(),
        ),
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
