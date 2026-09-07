import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/common/widgets/external_ai_consent.dart';
import 'package:map_service_client/features/mypage/screens/external_ai_settings_screen.dart';

void main() {
  Future<BuildContext> host(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const Scaffold(body: Text('host'));
          },
        ),
      ),
    );
    return context;
  }

  Future<ExternalAiPermission> grant(
    WidgetTester tester,
    ExternalAiConsentGate gate,
    BuildContext context,
    ExternalAiScope scope,
  ) async {
    final pending = gate.ensure(context, scope);
    await tester.pumpAndSettle();
    await tester.tap(find.text('전송에 동의'));
    await tester.pumpAndSettle();
    return (await pending)!;
  }

  testWidgets(
    'revocation invalidates in-flight permission permanently and asks again',
    (tester) async {
      final gate = ExternalAiConsentGate(sessionVersion: () => 1);
      final context = await host(tester);
      final old = await grant(tester, gate, context, ExternalAiScope.trip);
      final vision = await grant(tester, gate, context, ExternalAiScope.vision);
      expect(old.isCurrentSession, isTrue);
      gate.revoke(ExternalAiScope.trip);
      expect(old.isCurrentSession, isFalse);
      expect(vision.isCurrentSession, isTrue);
      expect(gate.hasConsent(ExternalAiScope.trip), isFalse);
      final renewed = await grant(tester, gate, context, ExternalAiScope.trip);
      expect(renewed.isCurrentSession, isTrue);
      expect(old.isCurrentSession, isFalse);
    },
  );

  testWidgets(
    'revocation while a consent dialog is open cannot be undone by its stale accept',
    (tester) async {
      final gate = ExternalAiConsentGate(sessionVersion: () => 1);
      final context = await host(tester);
      final pending = gate.ensure(context, ExternalAiScope.vision);
      await tester.pumpAndSettle();
      gate.revoke(ExternalAiScope.vision);
      await tester.tap(find.text('전송에 동의'));
      await tester.pumpAndSettle();
      expect(await pending, isNull);
      expect(gate.hasConsent(ExternalAiScope.vision), isFalse);
      expect(
        (await grant(
          tester,
          gate,
          context,
          ExternalAiScope.vision,
        )).isCurrentSession,
        isTrue,
      );
    },
  );

  testWidgets(
    'settings requires a deliberate decision and revokes only chosen feature',
    (tester) async {
      final gate = ExternalAiConsentGate(sessionVersion: () => 1);
      final context = await host(tester);
      final trip = await grant(tester, gate, context, ExternalAiScope.trip);
      final vision = await grant(tester, gate, context, ExternalAiScope.vision);
      await tester.pumpWidget(
        MaterialApp(home: ExternalAiSettingsScreen(consentGate: gate)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('이미 서버나 외부 AI'), findsOneWidget);
      expect(find.textContaining('기기 권한'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('revoke-vision')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(vision.isCurrentSession, isTrue);
      await tester.tap(find.byKey(const ValueKey('revoke-vision')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('철회하기'));
      await tester.pumpAndSettle();
      expect(vision.isCurrentSession, isFalse);
      expect(trip.isCurrentSession, isTrue);
      expect(gate.hasConsent(ExternalAiScope.vision), isFalse);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const ValueKey('revoke-vision')))
            .onPressed,
        isNull,
      );
    },
  );
}
