import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';

/// 돌림판을 한 번 돌리라는 요청. 결과 칸은 돌리기 전에 정해 둔다.
///
/// 결과를 애니메이션이 끝난 각도에서 읽으면 칸 경계에 걸린 경우 화면과 결과가
/// 어긋날 수 있다. 먼저 뽑고 그 칸에 멈추게 돌리면 둘이 항상 같다. 칸이 모두
/// 같은 크기라 보이는 확률과 실제 확률도 같다.
class RouletteSpin {
  const RouletteSpin(this.index, {this.jitter = 0});

  final int index;

  /// 칸 가운데에서 얼마나 비껴 멈출지(칸 폭 기준, -0.35~0.35). 매번 가운데에
  /// 딱 멈추면 조작한 것처럼 보인다.
  final double jitter;
}

/// 돌림판이 [index] 칸에 멈추도록 하는 최종 회전량(라디안, 시계 방향).
///
/// 칸 i 는 위쪽 바늘에서 시계 방향으로 [i·칸폭, (i+1)·칸폭) 을 차지한다. 판을
/// r 만큼 돌리면 바늘 아래에는 판 기준 -r 위치가 온다. 그래서 칸 가운데를
/// 바늘에 맞추려면 r ≡ -(i+0.5)·칸폭 (mod 2π) 이다. 지금 각도 [from] 에서 앞으로만
/// 돌도록 [turns] 바퀴를 더한다.
double rouletteStopAngle({
  required int index,
  required int count,
  required double from,
  int turns = 4,
  double jitter = 0,
}) {
  final segment = 2 * math.pi / count;
  final target = -(index + 0.5 + jitter.clamp(-0.35, 0.35)) * segment;
  final delta = (target - from) % (2 * math.pi);
  return from + turns * 2 * math.pi + delta;
}

/// 회전량 [angle] 일 때 위쪽 바늘이 가리키는 칸.
int rouletteSegmentAt(double angle, int count) {
  final segment = 2 * math.pi / count;
  return ((-angle) % (2 * math.pi) / segment).floor() % count;
}

class RouletteWheel extends StatefulWidget {
  const RouletteWheel({
    super.key,
    required this.labels,
    required this.spin,
    this.onSettled,
    this.size = 280,
  });

  final List<String> labels;

  /// 돌리기 요청. 새 요청 객체가 들어올 때마다 한 번 돈다.
  final RouletteSpin? spin;

  /// 판이 멈춘 뒤 결과 칸을 알린다.
  final ValueChanged<int>? onSettled;
  final double size;

  @override
  State<RouletteWheel> createState() => _RouletteWheelState();
}

class _RouletteWheelState extends State<RouletteWheel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  );
  Animation<double>? _rotation;
  double _angle = 0;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onSettled?.call(widget.spin!.index);
      }
    });
    if (widget.spin != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  @override
  void didUpdateWidget(RouletteWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.labels.length != oldWidget.labels.length) {
      _controller.stop();
      _rotation = null;
      _angle = 0;
    }
    if (widget.spin != null && !identical(widget.spin, oldWidget.spin)) {
      _start();
    }
  }

  void _start() {
    final spin = widget.spin;
    if (!mounted || spin == null) return;
    final stop = rouletteStopAngle(
      index: spin.index,
      count: widget.labels.length,
      from: _current,
      jitter: spin.jitter,
    );
    // 움직임 줄이기를 켰거나 화면 읽기로 쓰는 사람에게는 돌아가는 모습이
    // 정보가 아니라 기다림일 뿐이다. 바로 멈춘 자리를 보여 준다.
    if (MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)) {
      _controller.stop();
      setState(() {
        _rotation = null;
        _angle = stop;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onSettled?.call(spin.index);
      });
      return;
    }
    _rotation = Tween(
      begin: _current,
      end: stop,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _angle = stop;
    _controller.forward(from: 0);
  }

  double get _current => _rotation?.value ?? _angle;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '돌림판, ${widget.labels.length}칸',
      child: SizedBox(
        width: widget.size,
        height: widget.size + 16,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: 16,
              child: DecoratedBox(
                // 흰 테두리와 그림자는 돌지 않으니 판 밖에 한 번만 그린다.
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondaryScale[500]!.withAlpha(0x26),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    size: Size.square(widget.size),
                    painter: _WheelPainter(widget.labels, _current),
                  ),
                ),
              ),
            ),
            // 바늘은 판 위쪽에 고정한다.
            const CustomPaint(size: Size(22, 26), painter: _NeedlePainter()),
          ],
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.labels, this.angle);

  final List<String> labels;

  /// 지금 회전량. 글자 방향을 매 프레임 이 값으로 정한다.
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    final count = labels.length;
    final center = size.center(Offset.zero);
    // 바깥 7px 은 흰 테두리 자리로 비워 둔다.
    final radius = size.width / 2 - 7;
    final segment = 2 * math.pi / count;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final colors = [
      AppColors.secondaryScale[0]!,
      AppColors.secondaryScale[200]!,
      AppColors.secondaryScale[100]!,
    ];
    // 칸 수가 많으면 글자를 줄여야 칸 안에 들어간다.
    final fontSize = count > 20 ? 10.0 : (count > 12 ? 12.0 : 14.0);

    for (var i = 0; i < count; i++) {
      final start = -math.pi / 2 + i * segment + angle;
      // 칸 수가 홀수면 첫 칸과 끝 칸이 같은 색으로 붙지 않게 세 색을 돌린다.
      final color = colors[(count.isOdd && i == count - 1) ? 2 : i % 2];
      canvas.drawArc(rect, start, segment, true, Paint()..color = color);
      canvas.drawArc(
        rect,
        start,
        segment,
        true,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      // 글자는 칸 가운데를 따라 눕힌다. 판의 왼쪽 절반에 온 칸은 그대로 두면
      // 거꾸로 읽히므로 반 바퀴 뒤집어 늘 바로 읽히게 한다.
      final text = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: AppColors.neutralScale[600],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: radius * 0.62);
      final mid = start + segment / 2;
      final onLeft = math.cos(mid) < 0;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(onLeft ? mid + math.pi : mid);
      text.paint(
        canvas,
        Offset(
          onLeft ? -radius * 0.92 : radius * 0.92 - text.width,
          -text.height / 2,
        ),
      );
      canvas.restore();
    }
    // 가장 옅은 칸은 흰 테두리와 거의 같은 색이라 판 가장자리를 선으로 잡아 준다.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.primaryScale[100]!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(center, 20, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      19,
      Paint()
        ..color = AppColors.primaryScale[100]!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_WheelPainter oldDelegate) =>
      oldDelegate.labels != labels || oldDelegate.angle != angle;
}

/// 판 위에 고정된 아래 방향 바늘. 흰 테두리가 있어 어느 칸 색 위에서도 보인다.
class _NeedlePainter extends CustomPainter {
  const _NeedlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(1, 1)
      ..lineTo(size.width - 1, 1)
      ..lineTo(size.width / 2, size.height - 1)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.secondaryScale[900]!);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_NeedlePainter oldDelegate) => false;
}
