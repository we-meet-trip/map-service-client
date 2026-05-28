import 'package:flutter/material.dart';
import '../../../common/widgets/next_button.dart';
import '../../../common/widgets/prev_button.dart';

/// 모든 여행 계획 스텝 화면의 공통 레이아웃.
/// - 스크롤 가능한 콘텐츠 영역 + 하단 고정 버튼
/// - [onPrev]가 null이면 이전 버튼을 렌더하지 않음
class TripStepScaffold extends StatelessWidget {
  final List<Widget> children;
  final VoidCallback? onNext;
  final VoidCallback? onPrev;
  final String? nextInfo;

  const TripStepScaffold({
    super.key,
    required this.children,
    this.onNext,
    this.onPrev,
    this.nextInfo,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(child: Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                ...children,
                // 버튼 그림자(Y=24)가 콘텐츠와 겹치지 않도록 여유 공간 확보
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
          child: NextButton(onPressed: onNext, info: nextInfo),
        ),
        if (onPrev != null) ...[
          Padding(
            // 가로 패딩 없음 — PrevButton 내부에서 Center로 자체 정렬
            padding: const EdgeInsets.only(bottom: 20),
            child: PrevButton(onPressed: onPrev!),
          ),
        ] else
          const SizedBox(height: 26),
      ],
    ));
  }
}
