import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:map_service_client/core/api/api_client.dart';
import 'package:map_service_client/core/api/service_consent_api_service.dart';
import 'package:map_service_client/core/router/app_router.dart'
    show authRedirect;
import 'package:map_service_client/core/state/auth_store.dart';
import 'package:map_service_client/core/state/service_consent_store.dart';
import 'package:map_service_client/features/auth/screens/service_consent_screen.dart';
import 'package:map_service_client/features/auth/screens/policy_account_screen.dart';
import 'package:map_service_client/core/state/user_repository.dart' as profile;
import 'package:map_service_client/features/vision/services/vision_ws_service.dart';
import 'package:map_service_client/features/vision/models/vision_models.dart';
import 'package:map_service_client/core/api/chat_realtime_service.dart';

Map<String, dynamic> receipt({
  bool accepted = false,
  bool? age = true,
  String version = servicePolicyVersion,
}) => {
  'terms_version': version,
  'privacy_version': version,
  'minimum_age': 18,
  'accepted': accepted,
  'age_eligible': age,
  'accepted_at': accepted ? '2026-09-07T00:00:00Z' : null,
};
ServiceConsentStatus status({bool accepted = false, bool? age = true}) =>
    ServiceConsentStatus.fromJson(receipt(accepted: accepted, age: age));
ServiceConsentStore fakeStore({bool? age = true, bool accepted = false}) {
  final store = ServiceConsentStore(sessionChanges: ValueNotifier(0));
  store.loadStatus = () async => status(accepted: accepted, age: age);
  store.submitAcceptance = (_) async => status(accepted: true, age: age);
  return store;
}

Future<void> check(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
    await AuthStore.instance.save(
      const AuthTokens(
        accessToken: 'test-a',
        refreshToken: 'test-ra',
        userId: 1,
      ),
    );
    ServiceConsentStore.instance.invalidate();
  });

  test(
    'missing receipt fields and missing birth date cannot authorize service',
    () {
      expect(() => ServiceConsentStatus.fromJson({}), throwsFormatException);
      expect(
        () => ServiceConsentStatus.fromJson(
          receipt(accepted: true)..remove('age_eligible'),
        ),
        throwsFormatException,
      );
      expect(
        () => ServiceConsentStatus.fromJson({
          ...receipt(accepted: true),
          'accepted_at': null,
        }),
        throwsFormatException,
      );
      expect(
        ServiceConsentStatus.fromJson(
          receipt(accepted: true, age: null),
        ).permitsService,
        isFalse,
      );
      expect(
        ServiceConsentStatus.fromJson(
          receipt(accepted: true, age: false),
        ).permitsService,
        isFalse,
      );
      expect(
        ServiceConsentStatus.fromJson(
          receipt(accepted: true, version: 'future'),
        ).permitsService,
        isFalse,
      );
    },
  );

  test(
    'one status request is shared and acceptance never comes from an old account',
    () async {
      final pending = Completer<ServiceConsentStatus>();
      final store = fakeStore();
      var loads = 0;
      store.loadStatus = () {
        loads++;
        return pending.future;
      };
      final first = store.refresh();
      final second = store.refresh();
      expect(identical(first, second), isTrue);
      await AuthStore.instance.save(
        const AuthTokens(
          accessToken: 'test-b',
          refreshToken: 'test-rb',
          userId: 2,
        ),
      );
      pending.complete(status(accepted: true));
      await first;
      expect(loads, 1);
      expect(store.canAccess, isFalse);
      store.dispose();
    },
  );

  test('pending old GET cannot overwrite server-policy invalidation', () async {
    final pending = Completer<ServiceConsentStatus>();
    final store = fakeStore();
    store.loadStatus = () => pending.future;
    final request = store.refresh();
    store.invalidate(reason: 'SERVICE_POLICY_REQUIRED');
    pending.complete(status(accepted: true));
    await request;
    expect(store.canAccess, isFalse);
    store.dispose();
  });

  test(
    'explicit three checks required; stored underage cannot be overridden by self-attestation',
    () async {
      final store = fakeStore(age: false);
      await store.refresh();
      var posts = 0;
      store.submitAcceptance = (_) async {
        posts++;
        return status(accepted: true);
      };
      await expectLater(
        store.accept(adult: true, terms: true, privacy: true),
        throwsStateError,
      );
      expect(posts, 0);
      store.dispose();
    },
  );

  test(
    'API sends exact versioned acceptance only and keeps authentication',
    () async {
      final api = ServiceConsentApiService();
      await http.runWithClient(
        () async {
          final current = await api.fetch();
          final saved = await api.accept(current);
          expect(saved.permitsService, isTrue);
        },
        () => MockClient((request) async {
          expect(request.url.path, '/api/v1/consents');
          expect(request.headers['Authorization'], 'Bearer test-a');
          if (request.method == 'POST') {
            expect(jsonDecode(request.body), {
              'terms_version': servicePolicyVersion,
              'privacy_version': servicePolicyVersion,
              'is_18_or_older': true,
              'terms_accepted': true,
              'privacy_accepted': true,
            });
          }
          return http.Response(
            jsonEncode(receipt(accepted: request.method == 'POST')),
            200,
          );
        }),
      );
    },
  );

  test(
    'authenticated serving calls before consent are blocked with network zero',
    () async {
      var network = 0;
      await http.runWithClient(
        () async {
          for (final path in [
            '/api/v1/trip/generate',
            '/api/v1/trip/route',
            '/api/v1/trip/research',
            '/api/v1/chat/rooms',
            '/api/v1/weather/forecast',
          ]) {
            await expectLater(
              ApiClient.instance.post(path, body: const {}),
              throwsA(
                isA<ApiException>().having(
                  (e) => e.code,
                  'code',
                  'SERVICE_POLICY_REQUIRED',
                ),
              ),
            );
          }
        },
        () => MockClient((_) async {
          network++;
          return http.Response('{}', 200);
        }),
      );
      expect(network, 0);
    },
  );

  test(
    'server 403 invalidates previously accepted policy and denies the next serving call',
    () async {
      final store = ServiceConsentStore.instance;
      store.loadStatus = () async => status(accepted: true);
      await store.refresh();
      var network = 0;
      await http.runWithClient(
        () async {
          await expectLater(
            ApiClient.instance.get('/api/v1/chat/rooms'),
            throwsA(isA<ApiException>()),
          );
          expect(store.canAccess, isFalse);
          await expectLater(
            ApiClient.instance.get('/api/v1/chat/rooms'),
            throwsA(isA<ApiException>()),
          );
        },
        () => MockClient((_) async {
          network++;
          return http.Response(
            jsonEncode({'code': 'SERVICE_POLICY_REQUIRED'}),
            403,
          );
        }),
      );
      expect(network, 1);
    },
  );

  test(
    'a concurrent success cannot deliver service data after policy was revoked',
    () async {
      final store = ServiceConsentStore.instance;
      store.loadStatus = () async => status(accepted: true);
      await store.refresh();
      final pending = Completer<http.Response>();
      await http.runWithClient(() async {
        final request = ApiClient.instance.get('/api/v1/chat/rooms');
        final denied = expectLater(
          request,
          throwsA(
            isA<ApiException>().having(
              (e) => e.code,
              'code',
              'SERVICE_POLICY_REQUIRED',
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        store.invalidate(reason: 'AGE_RESTRICTED');
        pending.complete(http.Response('{"data":[]}', 200));
        await denied;
      }, () => MockClient((_) => pending.future));
    },
  );

  test(
    'clearing optional signup inputs removes prior values while normal partial edits preserve them',
    () {
      final original = profile.UserProfile(
        id: 'draft',
        nickname: '',
        birthdate: DateTime(2000),
        gender: '남성',
      );
      expect(original.copyWith(gender: '여성').birthdate, DateTime(2000));
      final cleared = original.copyWith(
        clearBirthdate: true,
        clearGender: true,
      );
      expect(cleared.birthdate, isNull);
      expect(cleared.gender, isNull);
    },
  );

  test(
    'account correction deletion and moderation remain accessible without consent',
    () async {
      final calls = <String>[];
      await http.runWithClient(
        () async {
          await ApiClient.instance.get('/api/v1/users/me');
          await ApiClient.instance.patch(
            '/api/v1/users/me',
            body: {'birthDate': '2000-01-01'},
          );
          await ApiClient.instance.delete('/api/v1/users/me');
          await ApiClient.instance.get('/api/v1/moderation/reports');
          await ApiClient.instance.get('/api/v1/moderation/blocks');
        },
        () => MockClient((r) async {
          calls.add('${r.method} ${r.url.path}');
          return http.Response('{}', 200);
        }),
      );
      expect(calls, hasLength(5));
    },
  );

  test('Vision and STOMP cannot connect before server consent', () async {
    var connections = 0;
    final vision = VisionWsService(
      channelFactory: (_, _) {
        connections++;
        throw StateError('must not connect');
      },
    );
    final errors = <String>[];
    vision.errors.listen(errors.add);
    await vision.connect('test');
    await vision.sendFrame(
      const VisionRequest(sessionId: 'test', frameB64: '', voiceText: '질문'),
    );
    final chat = ChatRealtimeService();
    chat.connect(1);
    expect(chat.state, ChatConnectionState.authRequired);
    expect(connections, 0);
    vision.dispose();
    chat.dispose();
  });

  testWidgets(
    'existing adult must tick each box; double tap submits once and no acceptance is fabricated',
    (tester) async {
      final store = fakeStore();
      final pending = Completer<ServiceConsentStatus>();
      var posts = 0;
      var entered = 0;
      store.submitAcceptance = (_) {
        posts++;
        return pending.future;
      };
      await tester.pumpWidget(
        MaterialApp(
          home: ServiceConsentScreen(store: store, onContinue: () => entered++),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('본인인증을 뜻하지 않습니다'), findsOneWidget);
      final submit = find.widgetWithText(FilledButton, '동의하고 계속');
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      await check(tester, 'policy-adult');
      await check(tester, 'policy-terms');
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      await check(tester, 'policy-privacy');
      final send = tester.widget<FilledButton>(submit).onPressed!;
      send();
      send();
      await tester.pump();
      expect(posts, 1);
      expect(entered, 0);
      expect(store.canAccess, isFalse);
      pending.complete(status(accepted: true));
      await tester.pumpAndSettle();
      expect(entered, 1);
      expect(store.canAccess, isTrue);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  test(
    'missing birthday cannot be replaced by three acceptance checks',
    () async {
      final store = fakeStore(age: null, accepted: true);
      var posts = 0;
      store.submitAcceptance = (_) async {
        posts++;
        return status(accepted: true);
      };
      await store.refresh();
      expect(store.canAccess, isFalse);
      await expectLater(
        store.accept(adult: true, terms: true, privacy: true),
        throwsStateError,
      );
      expect(posts, 0);
      store.dispose();
    },
  );

  testWidgets(
    'first birthday input waits for a server result before showing consent',
    (tester) async {
      bool? eligible;
      final store = fakeStore(age: null, accepted: true);
      store.loadStatus = () async => status(age: eligible);
      final saving = Completer<void>();
      var saved = 0;
      var entered = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ServiceConsentScreen(
            store: store,
            onContinue: () => entered++,
            saveBirthDate: (date) async {
              expect(date, DateTime(2000, 1, 1));
              saved++;
              await saving.future;
              eligible = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(store.canAccess, isFalse);
      expect(find.byKey(const Key('policy-adult')), findsNothing);
      await check(tester, 'policy-birth');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '01/01/2000');
      await tester.tap(find.text('OK'));
      await tester.pump();
      expect(saved, 1);
      expect(entered, 0);
      expect(store.canAccess, isFalse);
      expect(find.byKey(const Key('policy-adult')), findsNothing);
      saving.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('policy-adult')), findsOneWidget);
      expect(store.canAccess, isFalse);
      expect(entered, 0);
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(const Key('policy-adult')))
            .value,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  test(
    'missing-age server response invalidates an accepted session for all transports',
    () {
      expect(
        ServiceConsentStore.isPolicyDenial(403, 'AGE_INFORMATION_REQUIRED'),
        isTrue,
      );
      expect(
        ChatEvent.policyErrorCode('{"code":"AGE_INFORMATION_REQUIRED"}'),
        'AGE_INFORMATION_REQUIRED',
      );
    },
  );

  testWidgets(
    'known minor cannot accept and retains account-management exits',
    (tester) async {
      final store = fakeStore(age: false);
      await tester.pumpWidget(
        MaterialApp(
          home: ServiceConsentScreen(
            store: store,
            onContinue: () => fail('underage entered'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('만 18세 미만'), findsOneWidget);
      expect(find.byKey(const Key('policy-adult')), findsNothing);
      expect(find.text('생년월일 정정 · 계정 탈퇴'), findsOneWidget);
      expect(find.text('신고 처리 상태 · 차단 관리'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'failed acceptance keeps the gate closed and explains version mismatch',
    (tester) async {
      final store = fakeStore();
      var entered = 0;
      store.submitAcceptance = (_) async => throw const ApiException(
        statusCode: 409,
        code: 'POLICY_VERSION_MISMATCH',
        message: 'changed',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ServiceConsentScreen(store: store, onContinue: () => entered++),
        ),
      );
      await tester.pumpAndSettle();
      for (final key in ['policy-adult', 'policy-terms', 'policy-privacy']) {
        await check(tester, key);
      }
      await tester.tap(find.text('동의하고 계속'));
      await tester.pumpAndSettle();
      expect(entered, 0);
      expect(store.canAccess, isFalse);
      expect(find.text('정책이 변경됐어요. 최신 내용을 다시 확인해주세요.'), findsOneWidget);
      await tester.ensureVisible(find.text('다시 확인'));
      await tester.tap(find.text('다시 확인'));
      await tester.pumpAndSettle();
      for (final key in ['policy-adult', 'policy-terms', 'policy-privacy']) {
        expect(
          tester.widget<CheckboxListTile>(find.byKey(Key(key))).value,
          isFalse,
        );
      }
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'an acceptance completing after account change never enters the service',
    (tester) async {
      final store = fakeStore();
      final pending = Completer<ServiceConsentStatus>();
      var entered = 0;
      store.submitAcceptance = (_) => pending.future;
      await tester.pumpWidget(
        MaterialApp(
          home: ServiceConsentScreen(store: store, onContinue: () => entered++),
        ),
      );
      await tester.pumpAndSettle();
      for (final key in ['policy-adult', 'policy-terms', 'policy-privacy']) {
        await check(tester, key);
      }
      await tester.tap(find.text('동의하고 계속'));
      await tester.pump();
      await tester.runAsync(
        () => AuthStore.instance.save(
          const AuthTokens(
            accessToken: 'test-b',
            refreshToken: 'test-rb',
            userId: 2,
          ),
        ),
      );
      pending.complete(status(accepted: true));
      await tester.pump();
      expect(entered, 0);
      expect(store.canAccess, isFalse);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'account correction remains independent, sends only birth date and reloads server consent',
    (tester) async {
      final calls = <String>[];
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            const MaterialApp(home: PolicyAccountScreen()),
          );
          await tester.runAsync(
            () async => Future<void>.delayed(Duration.zero),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('잘못된 생년월일 정정'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('OK'));
          await tester.pumpAndSettle();
          await tester.runAsync(
            () async => Future<void>.delayed(Duration.zero),
          );
          await tester.pumpAndSettle();
          expect(calls, [
            'GET /api/v1/users/me',
            'PATCH /api/v1/users/me',
            'GET /api/v1/consents',
          ]);
          expect(find.textContaining('생년월일을 저장했습니다'), findsOneWidget);
          expect(ServiceConsentStore.instance.canAccess, isFalse);
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          if (request.url.path == '/api/v1/consents') {
            return http.Response(jsonEncode(receipt()), 200);
          }
          if (request.method == 'PATCH') {
            expect(jsonDecode(request.body), {'birthDate': '2000-01-01'});
          }
          return http.Response(
            jsonEncode({'id': 1, 'birthDate': '2000-01-01'}),
            200,
          );
        }),
      );
    },
  );

  testWidgets('failed account deletion never logs out or claims deletion', (
    tester,
  ) async {
    var deletes = 0;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(const MaterialApp(home: PolicyAccountScreen()));
        await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();
        await tester.tap(find.text('계정 탈퇴'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('취소'));
        await tester.pumpAndSettle();
        expect(deletes, 0);
        await tester.tap(find.text('계정 탈퇴'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('탈퇴하기'));
        await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();
        expect(deletes, 1);
        expect(AuthStore.instance.isLoggedIn.value, isTrue);
        expect(find.textContaining('계정은 유지됩니다'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
      () => MockClient((request) async {
        if (request.method == 'DELETE') {
          deletes++;
          return http.Response('{"code":"UNAVAILABLE"}', 503);
        }
        return http.Response('{"id":1}', 200);
      }),
    );
  });

  testWidgets(
    'failed lookup never builds protected map, Vision or invite screen; retry stays gated',
    (tester) async {
      for (final path in ['/vision', '/google-map', '/invite/token']) {
        var built = 0;
        final store = fakeStore();
        store.loadStatus = () async => throw const ApiException(
          statusCode: 503,
          code: 'UNAVAILABLE',
          message: 'retry',
        );
        final router = GoRouter(
          initialLocation: path,
          refreshListenable: store,
          redirect: (context, state) => authRedirect(
            authed: true,
            noticeSeen: true,
            location: state.matchedLocation,
            policyAccepted: store.canAccess,
          ),
          routes: [
            GoRoute(
              path: path,
              builder: (_, _) {
                built++;
                return const Text('protected');
              },
            ),
            GoRoute(
              path: '/service-consent',
              builder: (_, _) =>
                  ServiceConsentScreen(store: store, onContinue: () {}),
            ),
          ],
        );
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        expect(built, 0);
        expect(find.text('다시 확인'), findsOneWidget);
        await tester.tap(find.text('다시 확인'));
        await tester.pumpAndSettle();
        expect(built, 0);
        await tester.pumpWidget(const SizedBox());
        router.dispose();
        store.dispose();
      }
    },
  );

  test('18th birthday uses Korea calendar date rather than UTC day', () {
    final birth = DateTime(2008, 9, 8);
    expect(isAtLeast18(birth, now: DateTime.utc(2026, 9, 7, 14, 59)), isFalse);
    expect(isAtLeast18(birth, now: DateTime.utc(2026, 9, 7, 15)), isTrue);
  });

  test(
    'STOMP policy denials are recognized with or without event envelopes',
    () {
      expect(
        ChatEvent.policyErrorCode('{"code":"AGE_RESTRICTED"}'),
        'AGE_RESTRICTED',
      );
      expect(
        ChatEvent.policyErrorCode(
          '{"type":"ERROR","code":"SERVICE_POLICY_REQUIRED"}',
        ),
        'SERVICE_POLICY_REQUIRED',
      );
      expect(
        ChatEvent.policyErrorCode(
          '{"data":{"error":"SERVICE_POLICY_REQUIRED"}}',
        ),
        'SERVICE_POLICY_REQUIRED',
      );
      expect(ChatEvent.policyErrorCode('{"code":"CHAT_FORBIDDEN"}'), isNull);
      expect(ChatEvent.policyErrorCode('malformed'), isNull);
    },
  );

  test(
    'leap-day birthday matches server plusYears clamp and exact KST midnight',
    () {
      final birth = DateTime(2008, 2, 29);
      expect(
        isAtLeast18(birth, now: DateTime.utc(2026, 2, 27, 14, 59, 59)),
        isFalse,
      );
      expect(isAtLeast18(birth, now: DateTime.utc(2026, 2, 27, 15)), isTrue);
    },
  );
}
