import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:map_service_client/core/state/auth_store.dart';
import 'package:map_service_client/core/state/user_repository.dart';
import 'package:map_service_client/features/mypage/screens/profile_edit_screen.dart';

http.Response account(String email) => http.Response(
  jsonEncode({'id': 1, 'nickname': '시험 계정', 'email': email}),
  200,
  headers: {'content-type': 'application/json'},
);

Future<void> signIn(int id) => AuthStore.instance.save(
  AuthTokens(
    accessToken: 'synthetic-$id',
    refreshToken: 'synthetic-r-$id',
    userId: id,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
    await signIn(1);
    UserRepository.instance.profile.value = UserProfile.empty().copyWith(
      email: 'local-edit@example.invalid',
      phone: '01000000000',
      homeAddress: '기기 주소',
    );
  });

  testWidgets('계정 이메일은 서버 값만 읽기 전용으로 표시하고 기기 정보는 보존한다', (tester) async {
    final requests = <http.Request>[];
    await http.runWithClient(
      () async {
        await tester.pumpWidget(const MaterialApp(home: ProfileEditScreen()));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('server@example.invalid'));
        expect(find.text('local-edit@example.invalid'), findsNothing);
        await tester.tap(find.text('server@example.invalid'));
        await tester.pump();
        expect(find.byType(Dialog), findsNothing);
        expect(requests.map((r) => '${r.method} ${r.url.path}'), [
          'GET /api/v1/users/me',
        ]);
        expect(find.text('이 기기에 저장'), findsWidgets);
        expect(UserRepository.instance.profile.value.phone, '01000000000');
        expect(UserRepository.instance.profile.value.homeAddress, '기기 주소');
      },
      () => MockClient((request) async {
        requests.add(request);
        return account('server@example.invalid');
      }),
    );
  });

  testWidgets('조회 실패 시 로컬 이메일을 계정 이메일로 대체하지 않는다', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: ProfileEditScreen()));
      await tester.pumpAndSettle();
      expect(find.text('이메일을 확인하지 못했어요'), findsOneWidget);
      expect(find.text('local-edit@example.invalid'), findsNothing);
    }, () => MockClient((_) async => http.Response('{}', 503)));
  });

  testWidgets('이전 계정의 늦은 응답은 새 계정 화면에 노출되지 않는다', (tester) async {
    final first = Completer<http.Response>();
    var calls = 0;
    final client = MockClient((_) {
      calls++;
      return calls == 1
          ? first.future
          : Future.value(account('new@example.invalid'));
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: ProfileEditScreen()));
      await tester.pump();
      expect(calls, 1);
      // runAsync leaves the widget test zone, so bind the same mock there too.
      await tester.runAsync(
        () => http.runWithClient(() async {
          await signIn(2);
          await Future<void>.delayed(Duration.zero);
        }, () => client),
      );
      await tester.pumpAndSettle();
      expect(find.text('new@example.invalid'), findsOneWidget);
      first.complete(account('old@example.invalid'));
      await tester.pumpAndSettle();
      expect(find.text('old@example.invalid'), findsNothing);
      expect(find.text('new@example.invalid'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    }, () => client);
  });
}
