import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/data/models/weather_alert.dart';
import 'package:map_service_client/features/trip/widgets/weather_alert_banner.dart';

/// 날씨 배너 — 서버가 보낸 알림이 화면에서 어떤 선택지가 되는지
///
/// 배너는 지도 화면 위에 얹히지만 지도 SDK 는 실기기에서만 뜨므로 배너만 떼어
/// 확인한다. 그림 비교(골든)로 굳히지 않는다 — 글꼴이 기기마다 달라 통과 여부가
/// 검사할 대상과 무관한 이유로 갈린다. 대신 문구·버튼·잠금처럼 계약에 해당하는
/// 것만 본다.
void main() {
  WeatherAlert alert(String kind) => WeatherAlert(
        kind: kind,
        date: DateTime(2026, 9, 5),
        popBefore: 10,
        popAfter: 60,
      );

  Future<void> pump(
    WidgetTester tester, {
    required WeatherAlert value,
    VoidCallback? onReplan,
    VoidCallback? onDismiss,
    bool busy = false,
  }) =>
      tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: WeatherAlertBanner(
            alert: value,
            onReplan: onReplan ?? () {},
            onDismiss: onDismiss ?? () {},
            busy: busy,
          ),
        ),
      ));

  testWidgets('비 예보로 바뀌면 근거와 두 선택지를 보여준다', (tester) async {
    await pump(tester, value: alert(WeatherAlert.rainAppeared));

    expect(find.text('비 예보로 바뀌었어요'), findsOneWidget);
    // 날짜와 강수확률 변화가 함께 보여야 사용자가 판단할 수 있다.
    expect(find.text('9월 5일 · 강수확률 10% → 60%'), findsOneWidget);
    expect(find.text('다시 추천받기'), findsOneWidget);
    expect(find.text('이대로 갈게요'), findsOneWidget);
  });

  testWidgets('비 예보가 사라진 경우도 같은 선택지를 준다', (tester) async {
    await pump(tester, value: alert(WeatherAlert.rainCleared));

    expect(find.text('비 예보가 사라졌어요'), findsOneWidget);
    // 반가운 소식이라도 코스를 자동으로 바꾸지 않는다 — 결정은 사용자 몫이다.
    expect(find.text('다시 추천받기'), findsOneWidget);
    expect(find.text('이대로 갈게요'), findsOneWidget);
  });

  testWidgets('버튼을 누르면 각각의 처리가 불린다', (tester) async {
    var replanned = 0;
    var dismissed = 0;
    await pump(
      tester,
      value: alert(WeatherAlert.rainAppeared),
      onReplan: () => replanned++,
      onDismiss: () => dismissed++,
    );

    await tester.tap(find.text('다시 추천받기'));
    await tester.tap(find.text('이대로 갈게요'));

    expect(replanned, 1);
    expect(dismissed, 1);
  });

  testWidgets('재추천이 도는 중에는 두 버튼이 함께 잠긴다', (tester) async {
    var replanned = 0;
    var dismissed = 0;
    await pump(
      tester,
      value: alert(WeatherAlert.rainAppeared),
      onReplan: () => replanned++,
      onDismiss: () => dismissed++,
      busy: true,
    );

    // 진행 중임을 알리고, 그 사이 눌린 입력은 삼킨다 — "이대로 갈게요"가
    // 먹히면 방금 시작한 재추천의 결과와 어긋난다.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // 눌러도 아무 일이 없어야 한다. 버튼 종류가 아니라 눌림 자체가 막혔는지를
    // 본다 — 구현이 어떤 버튼 위젯을 쓰든 계약은 같다.
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull);

    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.tap(find.text('이대로 갈게요'), warnIfMissed: false);

    expect(replanned, 0);
    expect(dismissed, 0);
  });

  testWidgets('강수확률이 없으면 그 부분만 빠지고 날짜는 남는다', (tester) async {
    await pump(
      tester,
      value: const WeatherAlert(
        kind: WeatherAlert.rainAppeared,
        date: null,
        popBefore: null,
        popAfter: null,
      ),
    );

    // 값이 없는데 0% 라고 적으면 사실과 다르다. 근거 줄이 비더라도 제목과
    // 선택지는 그대로 서 있어야 한다.
    expect(find.text('비 예보로 바뀌었어요'), findsOneWidget);
    expect(find.text('다시 추천받기'), findsOneWidget);
  });
}
