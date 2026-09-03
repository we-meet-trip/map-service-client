import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:map_service_client/core/state/user_repository.dart';
import 'package:map_service_client/data/local/profile_local_store.dart';
import 'package:map_service_client/features/home/screens/home_screen.dart';

/// 홈 화면 인사말이 로그인한 사람의 이름을 부르는지 확인한다.
///
/// 그 전에는 이 자리에 고정된 이름이 박혀 있어, 누가 로그인해도 화면이 같은
/// 사람을 불렀다.
///
/// 날씨·일정 조회는 이 화면이 스스로 부르지만 테스트 환경에는 기기 기능이
/// 없어 실패한다. 화면이 그 실패를 스스로 처리하므로 인사말 확인에는 지장이
/// 없다 — 여기서는 인사말만 본다.
void main() {
  /// Text.rich 는 여러 조각을 이어 붙이므로 조각 하나만으로는 찾지 못한다.
  /// 이어 붙인 결과에서 찾는다.
  Finder richTextContaining(String needle) => find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains(needle),
      );

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
  }

  setUpAll(() async {
    // 보관소가 값이 바뀔 때마다 기기에 적으므로 저장 공간이 있어야 한다.
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = await Directory.systemTemp.createTemp('map_home_greeting_test');
    Hive.init(dir.path);
    await ProfileLocalStore.init();
  });

  setUp(() {
    UserRepository.instance.profile.value = UserProfile.empty();
  });

  testWidgets('로그인한 사람의 이름으로 인사한다', (tester) async {
    UserRepository.instance.profile.value =
        UserProfile.empty().copyWith(nickname: 'maptester1');

    await pumpHome(tester);

    expect(richTextContaining('maptester1 님'), findsOneWidget);
  });

  testWidgets('이름을 모르면 기본 이름으로 인사한다', (tester) async {
    await pumpHome(tester);

    expect(richTextContaining('여행자 님'), findsOneWidget);
  });

  testWidgets('이름이 바뀌면 다시 그린다', (tester) async {
    await pumpHome(tester);
    expect(richTextContaining('여행자 님'), findsOneWidget);

    // 앱 시작 직후 서버에서 이름을 받아 오는 순간을 재현한다.
    UserRepository.instance.applyAccount(nickname: 'maptester3');
    await tester.pump();

    expect(richTextContaining('maptester3 님'), findsOneWidget);
    expect(richTextContaining('여행자 님'), findsNothing);
  });
}
