// 장소 상세 시트에 사진 영역을 붙인 뒤에도 사진 없이 화면이 온전한지 본다.
//
// 사진은 부가 정보라 조회가 실패해도 시트가 그려져야 한다. 테스트 환경에서는
// 바깥 통신이 막혀 사진·요약·후기 조회가 모두 실패로 끝나므로, 이 상태가 곧
// "사진을 못 구한 장소"와 같은 화면이다. 이때 사진 자리가 남거나 예외가 새면
// 여기서 걸린다.
//
// 좌표를 넘기는 경로와 넘기지 않는 경로를 모두 확인한다. 좌표가 없으면 사진
// 요청 자체를 보내지 않는다는 것이 시트의 약속이기 때문이다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/features/trip/widgets/place_detail_sheet.dart';

const _name = '경복궁';
const _address = '서울 종로구 사직로 161';

Widget _host({double? lat, double? lng}) => MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showPlaceDetailSheet(
              context,
              name: _name,
              address: _address,
              category: '관광명소',
              latitude: lat,
              longitude: lng,
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    );

void main() {
  testWidgets('좌표를 넘겨도 사진을 못 구하면 사진 영역 없이 그려진다',
      (tester) async {
    await tester.pumpWidget(_host(lat: 37.5796, lng: 126.9770));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.text(_name), findsOneWidget);
    expect(find.text(_address), findsOneWidget);
    // 사진 머리말이 없다 = 영역째 접혔다.
    expect(find.text('사진'), findsNothing);
    expect(find.text('제공: Google'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('좌표가 없으면 사진을 요청하지 않고 기존 화면 그대로 그려진다',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.text(_name), findsOneWidget);
    expect(find.text('사진'), findsNothing);
    expect(find.text('블로그 리뷰'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
