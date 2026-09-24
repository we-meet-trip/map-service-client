// 랜덤 여행이 시도 → 시군구 → 미션 순서로 가는지, 세종처럼 시군구가 하나인
// 곳은 두 번째 돌림판을 건너뛰는지, 섬 지역에는 어디서나 되는 미션만
// 주는지 본다.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/common/constants/korea_regions.dart';
import 'package:map_service_client/common/constants/random_missions.dart';
import 'package:map_service_client/features/trip/screens/random_trip_screen.dart';

/// 정해 둔 순서대로 값을 내는 난수.
class _Scripted implements math.Random {
  _Scripted(this.ints);
  final List<int> ints;
  var _i = 0;

  @override
  int nextInt(int max) => ints[_i++ % ints.length] % max;
  @override
  double nextDouble() => 0.5;
  @override
  bool nextBool() => false;
}

Widget _host(math.Random random) => MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          // 돌아가는 모습 없이 바로 결과를 본다.
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: Scaffold(body: RandomTripScreen(random: random)),
        ),
      ),
    );

void main() {
  testWidgets('시도와 시군구를 뽑은 뒤 미션을 준다', (tester) async {
    final seoul = kProvinces.indexOf('서울특별시');
    await tester.pumpWidget(_host(_Scripted([seoul, 0, 0, 1])));

    await tester.tap(find.text('돌리기'));
    await tester.pump();
    await tester.pump();
    expect(find.text('서울 당첨!'), findsOneWidget);

    await tester.tap(find.text('이곳으로 할게요  →'));
    await tester.pump();
    expect(find.text('서울특별시 어디로 갈까요?'), findsOneWidget);

    await tester.tap(find.text('돌리기'));
    await tester.pump();
    await tester.pump();
    final city = kCitiesByProvince['서울특별시']!.first;
    expect(find.text('$city 당첨!'), findsOneWidget);

    await tester.tap(find.text('이곳으로 할게요  →'));
    await tester.pump();
    expect(find.text('이번 여행의 미션'), findsOneWidget);
    expect(find.text(kRandomMissions[0].title), findsOneWidget);
    expect(find.text('미션 다시 뽑기 (2번 남음)'), findsOneWidget);

    // 다시 뽑으면 같은 미션이 나오지 않고 남은 횟수가 준다.
    await tester.tap(find.text('미션 다시 뽑기 (2번 남음)'));
    await tester.pump();
    expect(find.text(kRandomMissions[0].title), findsNothing);
    expect(find.text('미션 다시 뽑기 (1번 남음)'), findsOneWidget);
  });

  testWidgets('다시 돌리면 남은 횟수가 준다', (tester) async {
    await tester.pumpWidget(_host(_Scripted([3, 4, 5])));
    await tester.tap(find.text('돌리기'));
    await tester.pump();
    await tester.pump();
    expect(find.text('다시 돌리기 (2번 남음)'), findsOneWidget);

    await tester.tap(find.text('다시 돌리기 (2번 남음)'));
    await tester.pump();
    await tester.pump();
    expect(find.text('다시 돌리기 (1번 남음)'), findsOneWidget);
  });

  testWidgets('시군구가 하나뿐인 세종은 두 번째 돌림판 없이 미션으로 간다',
      (tester) async {
    final sejong = kProvinces.indexOf('세종특별자치시');
    await tester.pumpWidget(_host(_Scripted([sejong, 0])));
    await tester.tap(find.text('돌리기'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('이곳으로 할게요  →'));
    await tester.pump();
    expect(find.text('이번 여행의 미션'), findsOneWidget);
  });

  test('섬 지역에는 어디서나 되는 미션만 준다', () {
    final pool = missionsFor('울릉군');
    expect(pool, isNotEmpty);
    expect(pool.every((m) => m.universal || m.query == null), isTrue);
    expect(missionsFor('종로구').length, kRandomMissions.length);
  });

  test('미션 식별자는 겹치지 않는다', () {
    final ids = kRandomMissions.map((m) => m.id).toSet();
    expect(ids.length, kRandomMissions.length);
  });

  test('모든 시도에 시군구 목록과 짧은 이름이 있다', () {
    for (final p in kProvinces) {
      expect(kCitiesByProvince[p], isNotEmpty, reason: p);
      expect(kProvinceShortNames[p], isNotNull, reason: p);
    }
  });

  test('시도와 시군구가 같으면 지역 이름을 한 번만 쓴다', () {
    expect(regionLabel('세종특별자치시', '세종특별자치시'), '세종특별자치시');
    expect(regionLabel('서울특별시', '종로구'), '서울특별시 종로구');
    expect(regionLabel('경기도', null), '경기도');
  });
}
