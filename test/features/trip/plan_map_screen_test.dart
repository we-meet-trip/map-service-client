// '여행 일정 계획하기' 지도 화면이 지역 밖 결과를 거르고, 장소 상세에서
// AI 후기 요약 없이 담기만 제공하는지 본다.
//
// 시험 환경에서는 지도가 뜨지 않으므로 같은 결과를 보여 주는 목록으로 고른다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/common/widgets/next_button.dart';
import 'package:map_service_client/common/widgets/review_summary_section.dart';
import 'package:map_service_client/core/api/places_api_service.dart';
import 'package:map_service_client/features/place_explore/widgets/place_bottom_sheet.dart';
import 'package:map_service_client/features/trip/screens/plan_map_screen.dart';
import 'package:map_service_client/features/trip/widgets/place_detail_sheet.dart';

PlaceSearchItem _item(String name, String address) => PlaceSearchItem(
      contentId: 'kakao:$name',
      name: name,
      address: address,
      roadAddress: '',
      latitude: 37.57,
      longitude: 126.98,
      category: '문화시설 > 박물관',
    );

void main() {
  group('placeInRegion', () {
    test('주소에 시도와 시군구가 모두 있어야 남긴다', () {
      expect(placeInRegion(_item('a', '서울 종로구 세종로 1'), '서울특별시', '종로구'), isTrue);
      expect(placeInRegion(_item('b', '부산 중구 중앙동 1'), '인천광역시', '중구'), isFalse);
      expect(placeInRegion(_item('c', '강원 고성군 토성면'), '경상남도', '고성군'), isFalse);
    });

    test('바뀐 시도 이름도 짧은 이름으로 알아본다', () {
      expect(
        placeInRegion(_item('d', '강원특별자치도 춘천시 중앙로 1'), '강원도', '춘천시'),
        isTrue,
      );
    });

    test('주소가 없는 결과는 판단하지 않고 남긴다', () {
      expect(placeInRegion(_item('e', ''), '서울특별시', '종로구'), isTrue);
    });
  });

  testWidgets('목록에서 고른 장소를 AI 요약 없이 담아 넘긴다', (tester) async {
    List<PlaceSearchItem>? handedOver;
    await tester.pumpWidget(
      MaterialApp(
        home: PlanMapScreen(
          province: '서울특별시',
          city: '종로구',
          initialQuery: '박물관',
          onPrev: () {},
          onNext: (selected) => handedOver = selected,
          api: ({required province, city, query}) async => [
            _item('국립고궁박물관', '서울 종로구 효자로 12'),
            _item('다른도시박물관', '부산 중구 중앙동 1'),
          ],
        ),
      ),
    );
    await tester.pump();

    // 지역 밖 결과는 빠진다.
    expect(find.text('찾은 장소 목록 (1)'), findsOneWidget);

    await tester.tap(find.text('찾은 장소 목록 (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('국립고궁박물관'));
    await tester.pumpAndSettle();

    expect(find.byType(PlaceBottomSheet), findsOneWidget);
    expect(find.byType(ReviewSummarySection), findsNothing);

    await tester.tap(find.text('+ 내 경로에 추가하기'));
    await tester.pump();
    Navigator.of(tester.element(find.byType(PlaceBottomSheet))).pop();
    await tester.pumpAndSettle();

    expect(find.text('1곳 담음'), findsOneWidget);
    await tester.tap(find.byType(NextButton));
    expect(handedOver?.single.name, '국립고궁박물관');
  });

  testWidgets('검색어를 치는 동안에는 검색창을 가리는 안내·단추를 숨긴다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlanMapScreen(
          province: '서울특별시',
          city: '종로구',
          onPrev: () {},
          onNext: (_) {},
          api: ({required province, city, query}) async => const [],
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('찾은 장소가 없어요'), findsOneWidget);
    expect(find.byType(NextButton), findsOneWidget);

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(find.textContaining('찾은 장소가 없어요'), findsNothing);
    expect(find.byType(NextButton), findsNothing);

    // 검색을 마치면 포커스가 풀려 다시 보인다.
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('찾은 장소가 없어요'), findsOneWidget);
    expect(find.byType(NextButton), findsOneWidget);
  });

  testWidgets('다음 단계가 없으면 담지 않고 둘러보기만 한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlanMapScreen(
          province: '서울특별시',
          city: '종로구',
          initialQuery: '박물관',
          onPrev: () {},
          api: ({required province, city, query}) async => [
            _item('국립고궁박물관', '서울 종로구 효자로 12'),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(NextButton), findsNothing);

    await tester.tap(find.text('찾은 장소 목록 (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('국립고궁박물관'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaceBottomSheet), findsOneWidget);
    expect(find.text('+ 내 경로에 추가하기'), findsNothing);
  });

  testWidgets('일정 결과의 장소 상세도 AI 요약을 끌 수 있다', (tester) async {
    Widget host(bool showAiSummary) => MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showPlaceDetailSheet(
                  context,
                  name: '경복궁',
                  address: '서울 종로구 사직로 161',
                  showAiSummary: showAiSummary,
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        );

    await tester.pumpWidget(host(false));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.byType(ReviewSummarySection), findsNothing);

    await tester.pumpWidget(host(true));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(PlaceBottomSheet))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.byType(ReviewSummarySection), findsOneWidget);
  });
}
