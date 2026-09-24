// 여행 계획 첫 화면이 세 갈래(직접 계획·AI 추천·랜덤)를 모두 열 수 있는지 본다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/features/trip/screens/trip_start_screen.dart';

void main() {
  testWidgets('세 갈래 단추가 각자의 흐름을 연다', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: TripStartScreen(
          onPlan: () => opened.add('plan'),
          onStart: () => opened.add('recommend'),
          onRandom: () => opened.add('random'),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('여행 일정 계획하기'));
    await tester.tap(find.text('추천받기'));
    await tester.tap(find.text('랜덤으로 가기'));
    expect(opened, ['plan', 'recommend', 'random']);
  });
}
