import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/features/chat/widgets/chat_room_menu_sheet.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('나가기를 누르면 주입한 콜백이 불린다', (tester) async {
    var left = false;
    await tester.pumpWidget(_wrap(ChatRoomMenuSheet(
      onLeave: () => left = true,
      onReport: () {},
    )));

    await tester.tap(find.text('채팅방 나가기'));

    expect(left, isTrue);
  });

  testWidgets('onKick 이 없으면 내보내기 항목이 안 보인다', (tester) async {
    await tester.pumpWidget(_wrap(ChatRoomMenuSheet(
      onLeave: () {},
      onReport: () {},
    )));

    expect(find.text('내보내기'), findsNothing);
    expect(find.text('채팅방 나가기'), findsOneWidget);
    expect(find.text('신고하기'), findsOneWidget);
  });

  testWidgets('onKick 을 주면 내보내기가 보이고 누르면 불린다', (tester) async {
    var kicked = false;
    await tester.pumpWidget(_wrap(ChatRoomMenuSheet(
      onLeave: () {},
      onReport: () {},
      onKick: () => kicked = true,
    )));

    await tester.tap(find.text('내보내기'));

    expect(kicked, isTrue);
  });
}
