import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:map_service_client/common/widgets/external_ai_consent.dart';
import 'package:map_service_client/common/widgets/review_summary_section.dart';
import 'package:map_service_client/core/api/review_api_service.dart';
import 'package:map_service_client/core/api/moderation_api_service.dart';
import 'package:map_service_client/core/api/api_client.dart';
import 'package:map_service_client/core/state/auth_store.dart';
import 'package:map_service_client/core/state/service_consent_store.dart';
import 'package:map_service_client/features/mypage/screens/external_ai_settings_screen.dart';

http.Response jsonResponse(String body, int status) => http.Response(
  body,
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final gate = ExternalAiConsentGate.instance;
  final auth = AuthStore.instance;
  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
    for (final scope in ExternalAiScope.values) {
      gate.revoke(scope);
    }
    await auth.save(
      const AuthTokens(
        accessToken: 'fixture-a',
        refreshToken: 'fixture-r',
        userId: 1,
      ),
    );
    ServiceConsentStore.instance.loadStatus = () async =>
        ServiceConsentStatus.fromJson({
          'terms_version': servicePolicyVersion,
          'privacy_version': servicePrivacyVersion,
          'minimum_age': 18,
          'accepted': true,
          'age_eligible': true,
          'accepted_at': '2026-09-07T00:00:00Z',
        });
    await ServiceConsentStore.instance.refresh(force: true);
  });
  tearDown(() {
    auth.refreshHandler = null;
  });
  Widget host() => MaterialApp(
    home: Scaffold(
      body: ReviewSummarySection(
        query: '공개 시험 장소',
        resultBuilder: (lines) => Text(lines.join('\n')),
      ),
    ),
  );
  final button = find.byKey(const ValueKey('generate-review-summary'));
  Future<void> request(WidgetTester tester) async {
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> accept(WidgetTester tester) async {
    await tester.tap(find.text('전송에 동의'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('legacy cached GET renders without consent or POST', (
    tester,
  ) async {
    final methods = <String>[];
    await http.runWithClient(
      () async {
        await tester.pumpWidget(host());
        await tester.pumpAndSettle();
        expect(find.text('저장된 요약'), findsOneWidget);
        expect(button, findsNothing);
        expect(methods, ['GET']);
        expect(gate.hasConsent(ExternalAiScope.reviewSummary), isFalse);
      },
      () => MockClient((r) async {
        methods.add(r.method);
        return jsonResponse(
          jsonEncode({
            'bullets': ['저장된 요약'],
            'sourceCount': 7,
          }),
          200,
        );
      }),
    );
  });
  testWidgets(
    'cache miss never generates automatically and refusal sends zero POST',
    (tester) async {
      var posts = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(host());
          await tester.pumpAndSettle();
          await request(tester);
          expect(find.textContaining('공개 블로그 후기 발췌문'), findsOneWidget);
          expect(find.byType(CheckboxListTile), findsNothing);
          await tester.tap(find.text('동의하지 않음'));
          await tester.pumpAndSettle();
          expect(posts, 0);
          expect(
            find.byKey(const ValueKey('report-review-summary')),
            findsNothing,
          );
          expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
        },
        () => MockClient((r) async {
          if (r.method == 'POST') posts++;
          return http.Response('{"bullets":[]}', 200);
        }),
      );
    },
  );
  testWidgets(
    'explicit POST deduplicates button and retry preserves UUID and exact body',
    (tester) async {
      final bodies = <Map<String, dynamic>>[];
      final pending = Completer<http.Response>();
      await http.runWithClient(
        () async {
          await tester.pumpWidget(host());
          await tester.pumpAndSettle();
          await request(tester);
          await accept(tester);
          expect(bodies, hasLength(1));
          expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
          pending.complete(http.Response('{}', 503));
          await tester.pumpAndSettle();
          expect(find.textContaining('요청에 실패'), findsOneWidget);
          await request(tester);
          await tester.pumpAndSettle();
          expect(bodies, hasLength(2));
          expect(bodies.first, bodies.last);
          expect(bodies.first.keys.toSet(), {
            'query',
            'consent',
            'client_request_id',
          });
          expect(bodies.first['query'], '공개 시험 장소');
          expect(bodies.first['consent'], isTrue);
          expect(
            bodies.first['client_request_id'],
            matches(RegExp(r'^[0-9a-f-]{36}$')),
          );
          expect(find.text('새 요약'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('report-review-summary')),
            findsOneWidget,
          );
        },
        () => MockClient((r) async {
          if (r.method == 'GET') return http.Response('{"bullets":[]}', 200);
          bodies.add(jsonDecode(r.body));
          return bodies.length == 1
              ? pending.future
              : jsonResponse(
                  jsonEncode({
                    'bullets': ['새 요약'],
                  }),
                  200,
                );
        }),
      );
    },
  );
  testWidgets(
    'revoked scope discards pending response and next request needs fresh consent',
    (tester) async {
      final pending = Completer<http.Response>();
      var posts = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(host());
          await tester.pumpAndSettle();
          await request(tester);
          await accept(tester);
          gate.revoke(ExternalAiScope.reviewSummary);
          pending.complete(
            jsonResponse(
              jsonEncode({
                'bullets': ['폐기할 응답'],
              }),
              200,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('폐기할 응답'), findsNothing);
          await request(tester);
          expect(find.text('장소 리뷰 요약 외부 AI 전송 동의'), findsOneWidget);
          expect(posts, 1);
          await tester.tap(find.text('동의하지 않음'));
          await tester.pumpAndSettle();
        },
        () => MockClient((r) async {
          if (r.method == 'GET') return http.Response('{"bullets":[]}', 200);
          posts++;
          return pending.future;
        }),
      );
    },
  );
  testWidgets('account change discards pending summary', (tester) async {
    final pending = Completer<http.Response>();
    await http.runWithClient(
      () async {
        await tester.pumpWidget(host());
        await tester.pumpAndSettle();
        await request(tester);
        await accept(tester);
        await tester.runAsync(
          () => auth.save(
            const AuthTokens(
              accessToken: 'fixture-b',
              refreshToken: 'fixture-rb',
              userId: 2,
            ),
          ),
        );
        pending.complete(
          jsonResponse(
            jsonEncode({
              'bullets': ['이전 계정 응답'],
            }),
            200,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('이전 계정 응답'), findsNothing);
        expect(find.textContaining('로그인 상태가 바뀌었어요'), findsOneWidget);
      },
      () => MockClient(
        (r) async => r.method == 'GET'
            ? http.Response('{"bullets":[]}', 200)
            : pending.future,
      ),
    );
  });
  test('401 refresh cannot retransmit revoked summary body', () async {
    var allowed = true;
    var posts = 0;
    final started = Completer<void>();
    final refresh = Completer<AuthTokens?>();
    auth.refreshHandler = (_) {
      started.complete();
      return refresh.future;
    };
    await http.runWithClient(
      () async {
        final result = ReviewApiService.instance.generateSummary(
          '공개 시험 장소',
          clientRequestId: '00000000-0000-4000-8000-000000000001',
          canSend: () => allowed,
        );
        final checked = expectLater(
          result,
          throwsA(
            isA<ApiException>().having(
              (e) => e.code,
              'code',
              'REQUEST_PERMISSION_REVOKED',
            ),
          ),
        );
        await started.future;
        allowed = false;
        refresh.complete(
          const AuthTokens(
            accessToken: 'fixture-new',
            refreshToken: 'fixture-new-r',
            userId: 1,
          ),
        );
        await checked;
        expect(posts, 1);
      },
      () => MockClient((r) async {
        posts++;
        return http.Response('', 401);
      }),
    );
  });
  testWidgets(
    'cached summary report submits editable user explanation with no target IDs or AI call',
    (tester) async {
      final bodies = <Map<String, dynamic>>[];
      final paths = <String>[];
      await http.runWithClient(
        () async {
          await tester.pumpWidget(host());
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('report-review-summary')));
          await tester.pumpAndSettle();
          expect(
            find.textContaining('원문과의 일치 여부가 자동 검증되지는 않습니다'),
            findsOneWidget,
          );
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            '공개 시험 장소\n저장된 요약',
          );
          await tester.tap(find.byType(DropdownButtonFormField<ReportReason>));
          await tester.pumpAndSettle();
          await tester.tap(find.text('잘못된 정보').last);
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byType(TextField),
            '공개 시험 장소의 요약에 대한 사용자 설명',
          );
          await tester.tap(find.text('신고 접수'));
          await tester.pumpAndSettle();
          expect(find.text('신고가 접수됐어요'), findsOneWidget);
          expect(bodies.single.keys.toSet(), {
            'content_type',
            'reason',
            'client_request_id',
            'description',
          });
          expect(bodies.single['content_type'], 'REVIEW_SUMMARY');
          expect(bodies.single['description'], '공개 시험 장소의 요약에 대한 사용자 설명');
          expect(paths, [
            '/api/v1/reviews/summary',
            '/api/v1/moderation/reports',
          ]);
          expect(gate.hasConsent(ExternalAiScope.reviewSummary), isFalse);
        },
        () => MockClient((r) async {
          paths.add(r.url.path);
          if (r.method == 'GET') {
            return jsonResponse(
              jsonEncode({
                'bullets': ['저장된 요약'],
              }),
              200,
            );
          }
          bodies.add(jsonDecode(r.body));
          return jsonResponse(
            jsonEncode({
              'report_id': '00000000-0000-4000-8000-000000000001',
              'status': 'OPEN',
              'created_at': '2026-09-07T00:00:00Z',
            }),
            201,
          );
        }),
      );
    },
  );
  test(
    'review summary report requires description and never sends reference IDs',
    () {
      expect(
        () => ReportSubmission(
          target: const ReportTarget.reviewSummary(),
          reason: ReportReason.inaccurate,
          clientRequestId: '00000000-0000-4000-8000-000000000001',
        ).toJson(),
        throwsFormatException,
      );
      final body = ReportSubmission(
        target: const ReportTarget.reviewSummary(),
        reason: ReportReason.inaccurate,
        clientRequestId: '00000000-0000-4000-8000-000000000001',
        description: '사용자 설명',
      ).toJson();
      expect(body.keys.toSet(), {
        'content_type',
        'reason',
        'client_request_id',
        'description',
      });
      expect(body['content_type'], 'REVIEW_SUMMARY');
    },
  );
  testWidgets('third settings scope revokes only review summary permission', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const Scaffold();
          },
        ),
      ),
    );
    Future<ExternalAiPermission> grant(ExternalAiScope scope) async {
      final future = gate.ensure(context, scope);
      await tester.pumpAndSettle();
      await accept(tester);
      return (await future)!;
    }

    final trip = await grant(ExternalAiScope.trip);
    final review = await grant(ExternalAiScope.reviewSummary);
    await tester.pumpWidget(
      MaterialApp(home: ExternalAiSettingsScreen(consentGate: gate)),
    );
    await tester.pumpAndSettle();
    final revoke = find.byKey(const ValueKey('revoke-reviewSummary'));
    await tester.ensureVisible(revoke);
    await tester.tap(revoke);
    await tester.pumpAndSettle();
    await tester.tap(find.text('철회하기'));
    await tester.pumpAndSettle();
    expect(review.isCurrentSession, isFalse);
    expect(trip.isCurrentSession, isTrue);
  });
}
