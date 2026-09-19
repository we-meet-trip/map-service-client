import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/common/widgets/app_empty_state.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

  testWidgets('빈 목록과 불러오기 실패가 다르게 보인다', (tester) async {
    // 둘을 같은 문구로 보여 주면 사용자가 다시 시도할 생각을 못 한다.
    await pump(tester, const AppEmptyState(
      icon: Icons.forum_outlined,
      message: '아직 참여 중인 대화방이 없어요.',
    ));
    expect(find.text('다시 시도'), findsNothing);

    await pump(tester, AppEmptyState(
      icon: Icons.cloud_off_rounded,
      message: '대화방을 불러오지 못했어요.',
      onRetry: () {},
    ));
    expect(find.text('다시 시도'), findsOneWidget);
  });

  testWidgets('다시 시도를 누르면 호출된다', (tester) async {
    var called = 0;
    await pump(tester, AppEmptyState(
      icon: Icons.cloud_off_rounded,
      message: '실패',
      onRetry: () => called++,
    ));
    await tester.tap(find.text('다시 시도'));
    expect(called, 1);
  });

  testWidgets('실패 상태에서는 권장 행동 버튼을 함께 내지 않는다', (tester) async {
    await pump(tester, AppEmptyState(
      icon: Icons.tune_rounded,
      message: '실패',
      onRetry: () {},
      action: const Text('일정 만들기'),
    ));
    expect(find.text('일정 만들기'), findsNothing);
  });

  testWidgets('부모가 start 정렬이어도 가운데에 놓인다', (tester) async {
    // 대화방 목록의 부모 Column 이 crossAxisAlignment.start 라 왼쪽으로
    // 치우쳐 보였다. 호출부가 Center 로 감싸지 않아도 가운데여야 한다.
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppEmptyState(icon: Icons.forum_outlined, message: '비었어요'),
            ),
          ],
        ),
      ),
    ));
    final screen = tester.getSize(find.byType(Scaffold)).width;
    expect(tester.getCenter(find.text('비었어요')).dx, closeTo(screen / 2, 1));
  });
}
