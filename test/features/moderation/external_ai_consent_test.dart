import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/common/widgets/external_ai_consent.dart';

void main() {
  testWidgets(
    'refusal causes no AI send; explicit consent defaults to no location',
    (tester) async {
      final gate = ExternalAiConsentGate(sessionVersion: () => 1);
      var sends = 0;
      ExternalAiPermission? permission;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  permission = await gate.ensure(
                    context,
                    ExternalAiScope.vision,
                  );
                  if (permission != null) sends++;
                },
                child: const Text('질문'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('질문'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Google Gemini'), findsWidgets);
      await tester.tap(find.text('동의하지 않음'));
      await tester.pumpAndSettle();
      expect(sends, 0);
      await tester.tap(find.text('질문'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('전송에 동의'));
      await tester.pumpAndSettle();
      expect(sends, 1);
      expect(permission!.includeLocation, isFalse);
    },
  );
  testWidgets('Vision location opt-in and trip scopes are independent', (
    tester,
  ) async {
    final gate = ExternalAiConsentGate(sessionVersion: () => 1);
    ExternalAiPermission? permission;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () async {
                    permission = await gate.ensure(
                      context,
                      ExternalAiScope.vision,
                    );
                  },
                  child: const Text('Vision'),
                ),
                TextButton(
                  onPressed: () async {
                    await gate.ensure(context, ExternalAiScope.trip);
                  },
                  child: const Text('Trip'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Vision'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('전송에 동의'));
    await tester.pumpAndSettle();
    expect(permission!.includeLocation, isTrue);
    await tester.tap(find.text('Trip'));
    await tester.pumpAndSettle();
    expect(find.text('여행 추천 외부 AI 전송 동의'), findsOneWidget);
    await tester.tap(find.text('동의하지 않음'));
    await tester.pumpAndSettle();
  });
  testWidgets(
    'account switch invalidates accepted permission and requires a new decision',
    (tester) async {
      var version = 1;
      final gate = ExternalAiConsentGate(sessionVersion: () => version);
      ExternalAiPermission? first;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  first ??= await gate.ensure(context, ExternalAiScope.vision);
                },
                child: const Text('질문'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('질문'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('전송에 동의'));
      await tester.pumpAndSettle();
      expect(first!.isCurrentSession, isTrue);
      version++;
      expect(first!.isCurrentSession, isFalse);
      first = null;
      await tester.tap(find.text('질문'));
      await tester.pumpAndSettle();
      expect(find.text('Vision 외부 AI 전송 동의'), findsOneWidget);
      version++;
      await tester.tap(find.text('전송에 동의'));
      await tester.pumpAndSettle();
      expect(first, isNull);
    },
  );
}
