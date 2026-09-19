// 경로 자료의 출처 표기가 발급처별로 갈리는지 본다.
//
// 지도 경로선은 OpenStreetMap, 대중교통 노선·시각은 ODsay 에서 온다. 한 문구로
// 덮으면 표기가 틀린 것이 되고, 대중교통 쪽은 아예 표기가 없던 자리였다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/features/trip/widgets/route_data_attribution.dart';

void main() {
  Future<void> mount(WidgetTester tester, Widget child) => tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Center(child: child))),
      );

  testWidgets('지도 경로선은 OpenStreetMap 을 밝힌다', (tester) async {
    await mount(tester, const RouteDataAttribution());

    expect(find.text('경로 © OpenStreetMap contributors'), findsOneWidget);
  });

  testWidgets('대중교통 노선·시각은 ODsay 를 밝힌다', (tester) async {
    await mount(tester, const RouteDataAttribution.transit());

    expect(find.text('대중교통 정보 © ODsay'), findsOneWidget);
    expect(find.textContaining('OpenStreetMap'), findsNothing);
  });
}
