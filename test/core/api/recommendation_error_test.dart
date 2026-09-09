import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:map_service_client/core/api/api_client.dart';
import 'package:map_service_client/core/api/trip_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final cases = <String, bool>{
    'no_matching_places': false,
    'selection_invalid': false,
    'invalid_request': false,
    'upstream_unavailable': true,
    'quota_exceeded': false,
    'generation_timeout': true,
    'generation_failed': false,
    'recommendation_pending': false,
    'timeline_changed': false,
  };
  for (final path in ['generate', 'route', 'research', 'replan']) {
    test('$path는 실패 원인과 재시도 가능 여부를 보존하고 새 요청을 자동으로 보내지 않는다', () async {
      var calls = 0;
      for (final item in cases.entries) {
        await http.runWithClient(
          () async {
            await expectLater(
              ApiClient.instance.post('/api/v1/trip/$path'),
              throwsA(
                isA<ApiException>()
                    .having((e) => e.code, 'code', item.key)
                    .having((e) => e.retryable, 'retryable', item.value)
                    .having(
                      (e) => e.message,
                      'safe message',
                      isNot(contains('secret-marker')),
                    ),
              ),
            );
          },
          () => MockClient((_) async {
            calls++;
            return http.Response(
              jsonEncode({
                'error': 'trip_generation_failed',
                'message': 'secret-marker http://internal/',
                'code': item.key,
                'retryable': true,
              }),
              502,
            );
          }),
        );
      }
      expect(calls, cases.length);
    });
  }

  test('legacy와 미상 추천 오류는 내부 문구 대신 안전한 실패로 정규화한다', () async {
    for (final code in [null, 'unrecognized-provider-code']) {
      await http.runWithClient(
        () async {
          await expectLater(
            ApiClient.instance.post('/api/v1/trip/generate'),
            throwsA(
              isA<ApiException>()
                  .having((e) => e.code, 'code', 'generation_failed')
                  .having((e) => e.retryable, 'retryable', false)
                  .having((e) => e.message, 'safe message', '추천을 생성하지 못했어요.'),
            ),
          );
        },
        () => MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': 'trip_generation_failed',
              'message': 'secret-marker',
              if (code != null) 'code': code,
              'retryable': true,
            }),
            502,
          ),
        ),
      );
    }
  });

  test('대기 시간 초과는 아직 실행 중인 요청을 새 추천으로 재시도하지 않는다', () async {
    await http.runWithClient(
      () async {
        await expectLater(
          TripApiService.instance.replanTrip(1, canSend: () => true),
          throwsA(
            isA<TripApiException>()
                .having((e) => e.error, 'code', 'recommendation_pending')
                .having((e) => e.retryable, 'retryable', false)
                .having((e) => e.message, 'message', contains('아직 처리 중')),
          ),
        );
      },
      () => MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': 'trip_generation_timeout',
            'message': 'secret-marker',
            'retryable': true,
          }),
          504,
        ),
      ),
    );
  });

  test('여행 예외에도 서버의 명시적 일시 장애 여부가 전달된다', () async {
    await http.runWithClient(
      () async {
        await expectLater(
          TripApiService.instance.replanTrip(1, canSend: () => true),
          throwsA(
            isA<TripApiException>()
                .having((e) => e.error, 'code', 'upstream_unavailable')
                .having((e) => e.retryable, 'retryable', true),
          ),
        );
      },
      () => MockClient(
        (_) async => http.Response(
          jsonEncode({'code': 'upstream_unavailable', 'retryable': true}),
          503,
        ),
      ),
    );
  });

  test('다른 API의 동명 오류 코드는 추천 오류로 바꾸지 않는다', () async {
    await http.runWithClient(
      () async {
        await expectLater(
          ApiClient.instance.post('/api/v1/auth/example'),
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'domain message',
              '인증 요청을 확인해주세요.',
            ),
          ),
        );
      },
      () => MockClient(
        (_) async => http.Response(
          jsonEncode({'code': 'invalid_request', 'message': '인증 요청을 확인해주세요.'}),
          422,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
  });

  test('네트워크 원문은 사용자 오류에 노출되지 않는다', () async {
    await http.runWithClient(
      () async {
        await expectLater(
          ApiClient.instance.get('/api/v1/trip/example'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.code, 'code', 'NETWORK_ERROR')
                .having(
                  (e) => e.message,
                  'safe message',
                  isNot(contains('secret-marker')),
                ),
          ),
        );
      },
      () =>
          MockClient((_) async => throw http.ClientException('secret-marker')),
    );
  });
}
