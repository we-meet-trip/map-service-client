import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/features/notice/screens/permission_notice_screen.dart';

void main() {
  testWidgets('작은 화면과 큰 글씨에서도 권한 안내 확인 버튼에 도달할 수 있다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const PermissionNoticeScreen(),
      ),
    );
    await tester.scrollUntilVisible(find.text('확인했어요'), 300);
    expect(find.text('확인했어요').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
