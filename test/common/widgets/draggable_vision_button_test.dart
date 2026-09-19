import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/common/widgets/draggable_vision_button.dart';

void main() {
  const size = Size(402, 874);
  const viewPadding = EdgeInsets.only(top: 59, bottom: 34);

  // 버튼이 놓이는 Stack 은 MainLayout 과 같은 모양으로 세운다.
  Widget host({Widget? overlayTrigger}) => MediaQuery(
        data: const MediaQueryData(size: size, viewPadding: viewPadding),
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                ?overlayTrigger,
                const DraggableVisionButton(),
              ],
            ),
          ),
        ),
      );

  testWidgets('기본 자리는 하단 탭과 홈 인디케이터를 피한 오른쪽 아래다',
      (tester) async {
    await tester.pumpWidget(host());

    final rect = tester.getRect(find.byType(DraggableVisionButton));

    // 오른쪽 여백 16
    expect(rect.right, closeTo(size.width - 16, 0.5));

    // 탭바(70) + 홈 인디케이터(34) 위로 16 만큼 떠 있어야 한다.
    final contentBottom = size.height - 70 - viewPadding.bottom;
    expect(rect.bottom, closeTo(contentBottom - 16, 0.5));
    expect(rect.bottom, lessThan(contentBottom));

    // 예전 기본값이던 화면 중간(top 300)으로 돌아가지 않았다.
    expect(rect.top, greaterThan(size.height / 2));
  });

  testWidgets('모달이 떠 있는 동안에는 가려진다', (tester) async {
    late BuildContext hostContext;
    await tester.pumpWidget(host(
      overlayTrigger: Builder(builder: (context) {
        hostContext = context;
        return const SizedBox.shrink();
      }),
    ));

    Offstage offstageOf() => tester.widget<Offstage>(find.descendant(
          of: find.byType(DraggableVisionButton),
          matching: find.byType(Offstage),
        ));

    expect(offstageOf().offstage, isFalse);

    showDialog<void>(
      context: hostContext,
      builder: (_) => const AlertDialog(content: Text('모달')),
    );
    await tester.pumpAndSettle();

    expect(offstageOf().offstage, isTrue);
  });
}
