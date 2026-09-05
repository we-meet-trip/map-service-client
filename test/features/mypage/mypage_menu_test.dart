import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:map_service_client/data/local/profile_local_store.dart';
import 'package:map_service_client/features/mypage/screens/mypage_screen.dart';

/// 마이페이지 메뉴 구성을 고정한다.
///
/// 준비 중이던 알림 설정·공지/이벤트 자리는 없어졌고, 약관 및 정책이
/// 새로 생겼다. 자리만 확인한다 — 눌렀을 때의 동작은 외부 앱을 열어
/// 여기서 볼 수 없다.
void main() {
  setUpAll(() async {
    // 프로필 보관소가 값이 바뀔 때마다 기기에 적으므로 저장 공간이 있어야 한다.
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = await Directory.systemTemp.createTemp('map_mypage_menu_test');
    Hive.init(dir.path);
    await ProfileLocalStore.init();
  });

  testWidgets('약관 및 정책은 있고 알림 설정·공지/이벤트는 없다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MypageScreen())),
    );
    await tester.pump();

    expect(find.text('약관 및 정책'), findsOneWidget);
    expect(find.text('고객센터'), findsOneWidget);
    expect(find.text('알림 설정'), findsNothing);
    expect(find.text('공지/이벤트'), findsNothing);
  });
}
