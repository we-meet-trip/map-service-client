import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/common/widgets/external_ai_consent.dart';
import 'package:map_service_client/core/api/ai_consent_api_service.dart';
import 'package:map_service_client/core/api/api_client.dart';

/// 서버가 저장된 동의를 확인하고 요청을 받아 주는지 흉내 낸다.
///
/// 실제 서버는 추천을 돌릴 때마다 저장된 동의를 다시 확인한다. 화면 동의만
/// 받고 서버에 남기지 않으면 사용자는 동의하고도 요청마다 거절당한다.
class _Server implements ApiClient {
  _Server({this.failGrant = false});
  final bool failGrant;
  final List<String> calls = [];
  int revision = 0;
  bool accepted = false;
  Map<String, dynamic>? grantBody;
  String? revokeRevision;

  @override
  Future<List<dynamic>> getList(String path, {Map<String, String>? query}) async {
    calls.add('GET $path');
    return [
      {
        'scope': 'trip',
        'policy_version': '2026-09-08.1',
        'accepted': accepted,
        'include_location': false,
        'revision': revision,
      },
    ];
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    Duration? timeout,
    bool Function()? canSend,
  }) async {
    calls.add('POST $path');
    if (failGrant) {
      throw const ApiException(
        statusCode: 503,
        code: 'AI_CONSENT_UNAVAILABLE',
        message: '잠시 후 다시 시도해주세요.',
      );
    }
    // 단언은 시험 본문에서 한다. 여기서 던지면 앱의 실패 처리에 삼켜져
    // 무엇이 어긋났는지 보이지 않는다.
    grantBody = body as Map<String, dynamic>;
    revision += 1;
    accepted = true;
    return {};
  }

  @override
  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, String>? query,
    Object? body,
    Duration? timeout,
  }) async {
    calls.add('DELETE $path');
    revokeRevision = query?['expected_revision'];
    revision += 1;
    accepted = false;
    return {};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

  Future<ExternalAiPermission?> ask(
    WidgetTester tester,
    ExternalAiConsentGate gate,
    BuildContext context,
  ) async {
    final pending = gate.ensure(context, ExternalAiScope.trip);
    await tester.pumpAndSettle();
    await tester.tap(find.text('전송에 동의'));
    await tester.pumpAndSettle();
    return pending;
  }

  testWidgets('동의하면 서버에도 남는다', (tester) async {
    final server = _Server();
    final gate = ExternalAiConsentGate(sessionVersion: () => 1);
    AiConsentApiService(api: server).bind(gate);
    final context = await host(tester);

    final permission = await ask(tester, gate, context);

    expect(permission, isNotNull);
    expect(permission!.isCurrentSession, isTrue);
    expect(server.calls, contains('POST /api/v1/consents/ai/trip'));
    expect(server.accepted, isTrue);
    // 서버가 준 판과 개정 번호를 그대로 되돌려 보내야 받아들여진다.
    expect(server.grantBody, {
      'policy_version': '2026-09-08.1',
      'accepted': true,
      'include_location': false,
      'expected_revision': 0,
    });
  });

  testWidgets('서버에 남기지 못하면 동의로 치지 않는다', (tester) async {
    final server = _Server(failGrant: true);
    final gate = ExternalAiConsentGate(sessionVersion: () => 1);
    AiConsentApiService(api: server).bind(gate);
    final context = await host(tester);

    final permission = await ask(tester, gate, context);

    // 여기서 허가를 내주면 사용자는 동의하고도 요청마다 403을 받는다.
    expect(permission, isNull);
    expect(server.accepted, isFalse);
    expect(gate.hasConsent(ExternalAiScope.trip), isFalse);
  });

  testWidgets('철회하면 서버에서도 지운다', (tester) async {
    final server = _Server();
    final gate = ExternalAiConsentGate(sessionVersion: () => 1);
    AiConsentApiService(api: server).bind(gate);
    final context = await host(tester);
    await ask(tester, gate, context);

    gate.revoke(ExternalAiScope.trip);
    await tester.pumpAndSettle();

    expect(server.accepted, isFalse);
    expect(server.calls.where((c) => c.startsWith('DELETE')), isNotEmpty);
    // 동의로 개정 번호가 1이 됐으므로 철회는 1을 들고 가야 한다.
    expect(server.revokeRevision, '1');
  });
}
