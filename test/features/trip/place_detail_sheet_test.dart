// 일정 화면의 장소 상세가 탐색 화면과 같은 시트를 쓰는지 본다.
//
// 예전에는 같은 모양을 두 벌 따로 그렸고, 한쪽에만 손이 가면서 일정 쪽에서만
// 큰 사진 자리가 사라졌다. 같은 장소를 어느 화면에서 열든 담기는 정보가 같아야
// 하므로, 두 화면이 한 위젯을 쓰는지를 여기서 붙잡아 둔다.
//
// 다른 점은 하나뿐이다. 이 자리는 이미 짜인 일정을 들여다보는 곳이라 경로에
// 담는 동작이 없다.
//
// 테스트 환경에서는 바깥 통신이 모두 막히므로 사진·요약·후기 조회가 실패로
// 끝난다. 그 상태에서도 시트가 예외 없이 그려져야 한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/features/place_explore/widgets/place_bottom_sheet.dart';
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

Future<void> _open(WidgetTester tester, Widget host) async {
  await tester.pumpWidget(host);
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('일정 화면도 탐색 화면과 같은 시트를 연다', (tester) async {
    await _open(tester, _host(lat: 37.5796, lng: 126.9770));

    expect(find.byType(PlaceBottomSheet), findsOneWidget);
    expect(find.text(_name), findsOneWidget);
    expect(find.text(_address), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('이미 짜인 일정이라 경로에 담는 단추는 없다', (tester) async {
    await _open(tester, _host(lat: 37.5796, lng: 126.9770));

    expect(find.text('+ 내 경로에 추가하기'), findsNothing);
    expect(find.text('추가됨 ✓'), findsNothing);
  });

  testWidgets('좌표가 없으면 사진을 아예 청하지 않는다', (tester) async {
    await _open(tester, _host());

    // 청하지 않았으니 성공도 실패도 없다 — 사진 자리 자체가 없어야 한다.
    expect(find.text('제공: Google'), findsNothing);
    expect(find.text('사진을 불러오지 못했어요.'), findsNothing);
    expect(find.text(_name), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
