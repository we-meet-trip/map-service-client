// 저장된 일정을 열 때 덮어 두는 진행 표시가 어떤 결말에도 반드시 걷히는지 본다.
//
// 이 화면은 탭 껍데기(StatefulShellRoute) 안에 있어서 네비게이터가 두 겹이다.
// 진행 표시를 띄운 겹과 닫는 겹이 어긋나면 닫기 요청이 진행 표시가 아니라 탭
// 안쪽 페이지를 뽑는다. 그러면 표시가 화면에 남는데, 배리어가 눌러도 닫히지
// 않게 되어 있어 사용자에게는 앱이 멈춘 것으로 보인다. 겉으로는 아무 오류도
// 나지 않으므로 이 짝을 여기서 못으로 박아 둔다.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:map_service_client/common/widgets/app_loading_indicator.dart';
import 'package:map_service_client/features/saved/utils/open_schedule.dart';

const _listMark = '저장 목록';

class _ListScreen extends StatelessWidget {
  const _ListScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(_listMark),
              ElevatedButton(
                onPressed: () => openSchedule(context, 9),
                child: const Text('열기'),
              ),
            ],
          ),
        ),
      );
}

/// 실제 앱과 같은 두 겹 구조. 탭 껍데기가 가지마다 제 네비게이터를 만든다.
GoRouter _router() => GoRouter(
      initialLocation: '/saved',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => shell,
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/saved',
                builder: (context, state) => const _ListScreen(),
                routes: [
                  GoRoute(
                    path: 'trip',
                    builder: (context, state) =>
                        const Scaffold(body: Text('상세 화면')),
                  ),
                ],
              ),
            ]),
          ],
        ),
      ],
    );

/// 진행 표시는 끝없이 도는 그림이라 화면이 멎기를 기다리면 시간을 넘긴다.
/// 정해진 횟수만 넘긴다.
Future<void> _advance(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// 눌린 직후 상태는 확인하지 않는다. 이 시험대의 통신 대역은 실제로 나가지
/// 않고 곧바로 답을 주므로, 첫 화면이 그려지기 전에 진행 표시가 떴다 걷힌다.
/// 여기서 보려는 것은 어느 쪽으로 끝났든 남은 자국이 없느냐다.
Future<void> _tapOpen(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp.router(routerConfig: _router()));
  await tester.tap(find.text('열기'));
  await _advance(tester);
}

/// 연결 자체가 서지 않는 상황을 만든다. 공통 계층은 응답 지연만 서버 오류
/// 형태로 바꾸므로, 이런 실패는 다른 모양으로 올라온다.
class _FailingHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FailingHttpClient();
}

class _FailingHttpClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw const SocketException('연결할 수 없음');
}

void main() {
  testWidgets('조회가 서버 오류로 끝나도 진행 표시가 걷히고 알림이 뜬다', (tester) async {
    // 테스트 환경의 기본 통신 대역은 모든 요청에 400 을 준다.
    await _tapOpen(tester);

    expect(find.byType(AppLoadingIndicator), findsNothing,
        reason: '진행 표시가 걷혀야 한다');
    expect(find.byType(SnackBar), findsOneWidget,
        reason: '실패를 사용자에게 알려야 한다');
  });

  testWidgets('진행 표시를 닫는 요청이 탭 안쪽 페이지를 대신 닫지 않는다', (tester) async {
    await _tapOpen(tester);

    expect(find.text(_listMark), findsOneWidget,
        reason: '닫기 요청이 진행 표시가 아닌 목록 화면을 뽑아 버리면 안 된다');
  });

  testWidgets('연결이 서지 않아 다른 모양의 실패가 나도 진행 표시가 걷힌다', (tester) async {
    final saved = HttpOverrides.current;
    HttpOverrides.global = _FailingHttpOverrides();
    try {
      await _tapOpen(tester);

      expect(find.byType(AppLoadingIndicator), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(_listMark), findsOneWidget);
    } finally {
      HttpOverrides.global = saved;
    }
  });
}
