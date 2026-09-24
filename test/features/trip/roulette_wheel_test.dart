// 돌림판이 미리 뽑은 칸에 멈추는지 본다.
//
// 결과를 먼저 뽑고 그 칸에 멈추게 돌리므로, 멈춘 각도에서 다시 읽은 칸이
// 뽑은 칸과 같아야 화면과 결과가 어긋나지 않는다.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/features/trip/widgets/roulette_wheel.dart';

void main() {
  test('멈춘 각도에서 읽은 칸이 뽑은 칸과 같다', () {
    for (final count in [2, 5, 17, 25, 31]) {
      for (var index = 0; index < count; index++) {
        for (final from in [0.0, 1.3, -4.2, 20 * math.pi + 0.7]) {
          for (final jitter in [-0.35, 0.0, 0.35]) {
            final stop = rouletteStopAngle(
              index: index,
              count: count,
              from: from,
              jitter: jitter,
            );
            expect(rouletteSegmentAt(stop, count), index,
                reason: 'count=$count index=$index from=$from jitter=$jitter');
            // 앞으로만 돌고, 적어도 정한 바퀴 수는 돈다.
            expect(stop - from, greaterThanOrEqualTo(4 * 2 * math.pi));
          }
        }
      }
    }
  });

  testWidgets('움직임 줄이기가 켜져 있으면 바로 결과를 알린다', (tester) async {
    int? settled;
    Widget host(RouletteSpin? spin) => MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: Scaffold(
                body: RouletteWheel(
                  labels: const ['가', '나', '다'],
                  spin: spin,
                  onSettled: (i) => settled = i,
                ),
              ),
            ),
          ),
        );
    await tester.pumpWidget(host(null));
    await tester.pumpWidget(host(const RouletteSpin(2)));
    await tester.pump();
    expect(settled, 2);
  });

  testWidgets('애니메이션이 끝나면 뽑은 칸을 알린다', (tester) async {
    int? settled;
    Widget host(RouletteSpin? spin) => MaterialApp(
          home: Scaffold(
            body: RouletteWheel(
              labels: const ['가', '나', '다', '라'],
              spin: spin,
              onSettled: (i) => settled = i,
            ),
          ),
        );
    await tester.pumpWidget(host(null));
    await tester.pumpWidget(host(const RouletteSpin(1, jitter: 0.2)));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(settled, isNull);
    await tester.pumpAndSettle();
    expect(settled, 1);
  });
}
