import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/data/repositories/invite_repository.dart';
import 'package:map_service_client/features/auth/post_login_route.dart';
import 'package:map_service_client/features/invite/providers/invite_provider.dart';
import 'package:provider/provider.dart';

class _UnusedInviteRepository implements InviteRepository {
  @override
  Future<InviteResolveResult> preview(String token) => throw UnimplementedError();
  @override
  Future<InviteResolveResult> join(String token) => throw UnimplementedError();
}

/// 로그인이 끝나는 화면에서 이 함수를 부른다. 화면 없이 값만 확인한다.
Future<String> routeWith(WidgetTester tester, InviteProvider provider) async {
  late String result;
  await tester.pumpWidget(
    ChangeNotifierProvider<InviteProvider>.value(
      value: provider,
      child: Builder(
        builder: (context) {
          result = postLoginRoute(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return result;
}

void main() {
  testWidgets('대기 중인 초대 토큰이 있으면 그 초대 화면으로 보낸다', (tester) async {
    // 링크를 눌러 들어온 사람을 홈으로 보내면 초대가 그 자리에서 끊긴다.
    final provider = InviteProvider(_UnusedInviteRepository())..pendingToken = 'TOK';

    expect(await routeWith(tester, provider), '/invite/TOK');
  });

  testWidgets('한 번 쓴 토큰은 지워져 다음 로그인 때 다시 끌려가지 않는다', (tester) async {
    final provider = InviteProvider(_UnusedInviteRepository())..pendingToken = 'TOK';

    await routeWith(tester, provider);

    expect(provider.pendingToken, isNull);
    expect(await routeWith(tester, provider), '/');
  });

  testWidgets('대기 중인 초대가 없으면 홈으로 보낸다', (tester) async {
    final provider = InviteProvider(_UnusedInviteRepository());

    expect(await routeWith(tester, provider), '/');
  });

  testWidgets('빈 토큰은 없는 것으로 본다', (tester) async {
    final provider = InviteProvider(_UnusedInviteRepository())..pendingToken = '';

    expect(await routeWith(tester, provider), '/');
  });
}
