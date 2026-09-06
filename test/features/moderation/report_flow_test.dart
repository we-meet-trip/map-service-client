import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/api/api_client.dart';
import 'package:map_service_client/core/api/moderation_api_service.dart';
import 'package:map_service_client/core/api/trip_api_service.dart';
import 'package:map_service_client/features/trip/screens/trip_created_screen.dart';
import 'package:map_service_client/features/moderation/report_dialog.dart';
import 'package:map_service_client/features/moderation/moderation_center_screen.dart';

const id = '215bc33e-2ed3-4e21-b0e1-4a6dbfd4a110';
Map<String, dynamic> receipt() => {
  'report_id': id,
  'status': 'OPEN',
  'created_at': '2026-09-07T01:00:00Z',
};

class FakeApi implements ApiClient {
  final List<Map<String, Object>> bodies = [];
  Object? failure;
  Completer<Map<String, dynamic>>? pending;
  Object list = <dynamic>[];
  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    Duration? timeout,
  }) async {
    bodies.add(Map<String, Object>.from(body! as Map));
    if (failure != null) throw failure!;
    return pending == null ? receipt() : pending!.future;
  }

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) async => {'data': list};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget dialog(
  FakeApi api, {
  ReportTarget target = const ReportTarget.chat(roomId: 7, messageSeq: 21),
}) => MaterialApp(
  home: Scaffold(
    body: ContentReportDialog(
      target: target,
      service: ModerationApiService(api: api),
    ),
  ),
);

Future<void> selectReason(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButtonFormField<ReportReason>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('괴롭힘·욕설').last);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'server moderation resolution is presented without exposing internal codes',
    () {
      final report = ModerationReport.fromJson({
        ...receipt(),
        'status': 'ACTIONED',
        'resolution': 'HIDE_CHAT_MESSAGE',
      });
      expect(report.statusLabel, '조치 완료');
      expect(report.resolutionLabel, '대상 메시지가 숨겨졌어요.');
    },
  );
  testWidgets(
    'missing trip result shows neither invented stops nor report actions',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TripCreatedScreen())),
      );
      await tester.pump();
      expect(find.textContaining('표시할 일정 결과가 없어요'), findsOneWidget);
      expect(find.text('속초해변'), findsNothing);
      expect(find.text('이 결과 신고'), findsNothing);
    },
  );
  testWidgets('empty generated response is not reportable content', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TripCreatedScreen(
            response: TripGenerateResponse(
              tripId: id,
              totalDurationMinutes: 0,
              stops: [],
              weatherForecast: [],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('이 결과 신고'), findsNothing);
    expect(find.textContaining('표시할 일정 결과가 없어요'), findsOneWidget);
  });
  test(
    'references reject unsaved placeholders and enforce exactly one trip reference',
    () {
      expect(const ReportTarget.chat(roomId: 7, messageSeq: 0).valid, isFalse);
      expect(const ReportTarget.trip().valid, isFalse);
      expect(
        const ReportTarget.trip(scheduleId: 7, recommendJobId: id).valid,
        isFalse,
      );
      expect(
        const ReportTarget.trip(scheduleId: 0, recommendJobId: id).valid,
        isFalse,
      );
      expect(const ReportTarget.trip(recommendJobId: id).valid, isTrue);
    },
  );
  test(
    'Vision submission requires text and never serializes an image or target IDs',
    () async {
      final api = FakeApi();
      final service = ModerationApiService(api: api);
      await expectLater(
        service.report(
          ReportSubmission(
            target: const ReportTarget.vision(),
            reason: ReportReason.inaccurate,
            clientRequestId: id,
          ),
        ),
        throwsFormatException,
      );
      expect(api.bodies, isEmpty);
      await service.report(
        ReportSubmission(
          target: const ReportTarget.vision(),
          reason: ReportReason.inaccurate,
          clientRequestId: id,
          description: '답변에 대한 신고 이유',
        ),
      );
      expect(api.bodies.single.keys.toSet(), {
        'content_type',
        'reason',
        'client_request_id',
        'description',
      });
    },
  );
  test(
    'top-level lists are decoded and malformed shapes fail instead of pretending empty',
    () async {
      final api = FakeApi()..list = [receipt()];
      final service = ModerationApiService(api: api);
      expect((await service.reports()).single.reportId, id);
      api.list = [
        {'blocked_user_id': 9, 'created_at': '2026-09-07T01:00:00Z'},
      ];
      expect((await service.blocks()).single.userId, 9);
      api.list = {'wrong': 'shape'};
      await expectLater(service.reports(), throwsFormatException);
    },
  );
  testWidgets(
    'failed submission stays open, retry preserves payload and UUID',
    (tester) async {
      final api = FakeApi()..failure = StateError('timeout');
      await tester.pumpWidget(dialog(api));
      await selectReason(tester);
      await tester.enterText(find.byType(TextField), '공개 합성 설명');
      await tester.tap(find.text('신고 접수'));
      await tester.pumpAndSettle();
      expect(find.text('신고가 접수됐어요'), findsNothing);
      expect(find.textContaining('접수 결과를 확인하지 못했어요'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      api.failure = null;
      await tester.tap(find.text('같은 신고 재시도'));
      await tester.pumpAndSettle();
      expect(api.bodies.length, 2);
      expect(api.bodies[0], api.bodies[1]);
      expect(api.bodies[0]['message_seq'], 21);
      expect(find.text('신고가 접수됐어요'), findsOneWidget);
    },
  );
  testWidgets(
    'pending submission disables repeated taps and only shows acceptance after reply',
    (tester) async {
      final api = FakeApi()..pending = Completer();
      await tester.pumpWidget(dialog(api));
      await selectReason(tester);
      await tester.tap(find.text('신고 접수'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(api.bodies.length, 1);
      expect(find.text('신고가 접수됐어요'), findsNothing);
      api.pending!.complete(receipt());
      await tester.pumpAndSettle();
      expect(find.text('신고가 접수됐어요'), findsOneWidget);
    },
  );
  testWidgets('Vision empty explanation is blocked before API call', (
    tester,
  ) async {
    final api = FakeApi();
    await tester.pumpWidget(dialog(api, target: const ReportTarget.vision()));
    await selectReason(tester);
    await tester.tap(find.text('신고 접수'));
    await tester.pump();
    expect(api.bodies, isEmpty);
    expect(find.textContaining('필요한 설명'), findsOneWidget);
  });
  testWidgets('malformed receipt never claims success', (tester) async {
    final api = FakeApi()..pending = Completer();
    await tester.pumpWidget(dialog(api));
    await selectReason(tester);
    await tester.tap(find.text('신고 접수'));
    await tester.pump();
    api.pending!.complete({});
    await tester.pumpAndSettle();
    expect(find.text('신고가 접수됐어요'), findsNothing);
    expect(find.textContaining('접수 결과를 확인하지 못했어요'), findsOneWidget);
  });
  testWidgets('report history failure has retry and no false empty state', (
    tester,
  ) async {
    final api = FakeApi()..list = 'invalid';
    await tester.pumpWidget(
      MaterialApp(
        home: ModerationCenterScreen(service: ModerationApiService(api: api)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.text('접수한 신고가 없어요.'), findsNothing);
  });
}
