import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/features/place_explore/models/place_detail.dart';
import 'package:map_service_client/features/place_explore/widgets/place_bottom_sheet.dart';

/// 후기를 못 받아왔을 때도 장소 팝업이 열리는지 검증.
///
/// 시험 환경의 통신은 모두 실패하므로 요약도 후기도 비어 있는 상태가 된다.
/// 그때 팝업이 이름과 주소를 그대로 보여 주고, 요약 자리는 접히고, 후기
/// 자리에는 안내가 남아야 한다.
void main() {
  Future<void> pumpSheet(WidgetTester tester, PlaceDetail detail) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaceBottomSheet(
            detail: detail,
            isAdded: false,
            onToggle: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 시트는 접힌 채로 열려 후기 영역이 아직 그려지지 않는다. 끌어올려
  /// 아래쪽까지 그려지게 한다.
  Future<void> dragSheetUp(WidgetTester tester) async {
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await tester.pumpAndSettle();
  }

  const detail = PlaceDetail(
    id: 'stop_0',
    name: '속초해변',
    address: '강원특별자치도 속초시 청호동 해오름로 186',
    category: '여행 / 관광,명소 / 해수욕장,해변',
  );

  testWidgets('후기를 못 받아도 장소와 주소는 그대로 열린다', (tester) async {
    await pumpSheet(tester, detail);

    expect(find.text('속초해변'), findsOneWidget);
    expect(find.text('강원특별자치도 속초시 청호동 해오름로 186'), findsOneWidget);
    // 칩에는 계층 원문이 아니라 화면이 쓰는 관심사 이름이 들어간다.
    expect(find.text('해변'), findsOneWidget);
    expect(find.text('여행 / 관광,명소 / 해수욕장,해변'), findsNothing);
  });

  testWidgets('후기가 없으면 안내를 남기고 더보기를 감춘다', (tester) async {
    await pumpSheet(tester, detail);
    await dragSheetUp(tester);

    expect(find.text('블로그 리뷰'), findsOneWidget);
    expect(find.text('아직 등록된 후기가 없어요.'), findsOneWidget);
    expect(find.text('블로그 리뷰 더보기'), findsNothing);
  });

  testWidgets('요약을 못 받으면 요약 자리를 접는다', (tester) async {
    await pumpSheet(tester, detail);
    await dragSheetUp(tester);

    expect(find.text('AI 리뷰 요약'), findsNothing);
  });

  testWidgets('분류가 없는 장소는 빈 칩을 남기지 않는다', (tester) async {
    await pumpSheet(
      tester,
      const PlaceDetail(
        id: 'stop_1',
        name: '속초 버스 터미널',
        address: '강원특별자치도 속초시',
      ),
    );

    expect(find.text('속초 버스 터미널'), findsOneWidget);
    // 분류를 빈 글자로 그리면 글자 없는 칩만 남는다. 그 자리는 아예 없어야
    // 하므로 빈 글자가 그려지지 않았는지로 확인한다.
    expect(find.text(''), findsNothing);
  });
}
