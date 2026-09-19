// 로그인 화면 세 버튼의 크기가 서로 어긋나지 않는지 본다.
//
// Apple 버튼은 패키지가 만들어 주는 것이라 기본값(높이 44 · 모서리 8)이 따로
// 있다. 값을 넘기지 않으면 가운데 버튼만 낮고 각진 채로 놓인다. 셋이 같은
// 상수를 보는지 여기서 붙잡는다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/features/auth/widgets/auth_button_metrics.dart';
import 'package:map_service_client/features/auth/widgets/email_login_button.dart';
import 'package:map_service_client/features/auth/widgets/kakao_login_button.dart';

void main() {
  Future<void> mount(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 292, child: child)),
        ),
      ),
    );
    await tester.pump();
  }

  test('모서리는 알약이 되도록 높이의 절반을 넘는다', () {
    expect(kAuthButtonRadius, greaterThanOrEqualTo(kAuthButtonHeight / 2));
  });

  testWidgets('카카오 버튼이 공통 높이를 쓴다', (tester) async {
    await mount(tester, const KakaoLoginButton());

    expect(
      tester.getSize(find.byType(KakaoLoginButton)).height,
      kAuthButtonHeight,
    );
  });

  testWidgets('이메일 버튼이 카카오 버튼과 같은 높이다', (tester) async {
    await mount(tester, const EmailLoginButton());

    expect(
      tester.getSize(find.byType(EmailLoginButton)).height,
      kAuthButtonHeight,
    );
  });
}
