import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/common/widgets/app_loading_screen.dart';
import 'package:map_service_client/common/widgets/external_ai_consent.dart';
import 'package:map_service_client/core/api/api_client.dart';
import 'package:map_service_client/core/api/trip_api_service.dart';
import 'package:map_service_client/core/state/trip_repository.dart';
import 'package:map_service_client/features/place_explore/screens/place_explore_result_screen.dart';
import 'package:map_service_client/features/place_explore/utils/plan_place_id.dart';

/// 탐색 결과 화면이 고른 장소로 실제 동선을 요청하는지 검증.
///
/// 응답 본문은 로컬 스택의 `/api/v1/trip/route` 가 실제로 돌려준 모양이다.
void main() {
  final requested = <Uri>[];
  final sentBodies = <String>[];

  TripStop stop({
    required int order,
    required String name,
    double latitude = 38.19,
    double longitude = 128.60,
    String? category,
  }) =>
      TripStop(
        order: order,
        name: name,
        address: '$name 주소',
        time: '09:00',
        latitude: latitude,
        longitude: longitude,
        category: category,
      );

  void givenPlan(List<TripStop> stops) {
    TripRepository.instance.setLastPlan(TripPlanContext(
      startDate: DateTime(2026, 5, 1),
      endDate: DateTime(2026, 5, 1),
      activeStartHour: 9,
      activeEndHour: 20,
      transport: 'walk',
      province: '강원특별자치도',
      city: '속초시',
      stops: stops,
    ));
  }

  String routeBody() => jsonEncode({
        'trip_id': 'job-route-1',
        'total_duration_minutes': 41,
        'stops': [
          {
            'order': 1,
            'day': 1,
            'name': '영금정',
            'address': '영금정 주소',
            'time': '09:00',
            'latitude': 38.21,
            'longitude': 128.60,
            'place_id': 1,
            'transport_to_next': {
              'label': '이동: 도보',
              'duration_minutes': 12,
              'distance_km': 0.9,
              'path': [
                [38.21, 128.60],
                [38.205, 128.601],
              ],
            },
          },
          {
            'order': 2,
            'day': 1,
            'name': '속초해변',
            'address': '속초해변 주소',
            'time': '09:12',
            'latitude': 38.19,
            'longitude': 128.60,
            'place_id': 0,
          },
        ],
        'weather_forecast': <dynamic>[],
      });

  setUp(() {
    requested.clear();
    sentBodies.clear();
    TripRepository.instance.lastPlan = null;
  });
  tearDown(() => TripRepository.instance.lastPlan = null);

  /// 로딩 화면의 최소 대기 타이머를 소진시킨다.
  ///
  /// 대기가 끝나면 일정 화면으로 넘어가는데 그 화면은 지도를 그려 시험
  /// 환경에서 열리지 않는다. 그것만 넘기되 무엇을 넘기는지는 못 박는다 —
  /// 종류를 안 보고 삼키면 응답을 읽다 난 오류까지 함께 사라진다.
  Future<void> drainLoadingTimer(WidgetTester tester) async {
    final caught = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = caught.add;
    await tester.pump(const Duration(seconds: 3));
    FlutterError.onError = previousOnError;

    for (final details in caught) {
      expect(
        details.exception,
        isNot(anyOf(isA<ApiException>(), isA<TripApiException>(),
            isA<TypeError>(), isA<NoSuchMethodError>())),
        reason: '요청·응답 경로에서 난 오류는 회귀다: ${details.exception}',
      );
    }
  }

  Future<void> pump(WidgetTester tester, Set<String> selected) async {
    await tester.pumpWidget(MaterialApp(
      home: PlaceExploreResultScreen(selectedIds: selected, consentGate: ExternalAiConsentGate()),
    ));
    await tester.pump();
  }

  Future<void> acceptConsent(WidgetTester tester) async {
    await tester.pumpAndSettle();
    expect(requested, isEmpty, reason: '동의 전에는 요청을 보내지 않는다');
    expect(find.byType(AppLoadingScreen), findsNothing);
    await tester.tap(find.text('전송에 동의'));
    await tester.pump();
  }

  testWidgets('고른 장소로 동선을 한 번 요청한다', (tester) async {
    await HttpOverrides.runZoned(
      () async {
        givenPlan([
          stop(order: 1, name: '속초해변', category: '여행 / 관광,명소 / 해수욕장,해변'),
          stop(order: 2, name: '영금정', latitude: 38.21),
          stop(order: 3, name: '속초 중앙시장', latitude: 38.20),
        ]);

        await pump(tester, {planPlaceId(0), planPlaceId(1), planPlaceId(2)});
        await acceptConsent(tester);
        expect(find.byType(AppLoadingScreen), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 100));

        final routeCalls =
            requested.where((u) => u.path.endsWith('/trip/route')).toList();
        expect(routeCalls, hasLength(1));

        final body = jsonDecode(sentBodies.single) as Map<String, dynamic>;
        expect(body.keys,
            containsAll(['schedule', 'transport', 'location', 'places']));
        final places = body['places'] as List;
        expect(places.map((p) => (p as Map)['name']),
            ['속초해변', '영금정', '속초 중앙시장']);
        expect((places.first as Map)['category'],
            '여행 / 관광,명소 / 해수욕장,해변');

        // 로딩 화면이 최소 대기 시간을 두므로 그 타이머를 소진시킨다.
        // 대기가 끝나면 일정 화면으로 넘어가는데, 그 화면은 지도를 그려
        // 시험 환경에서 열리지 않는다. 여기서 볼 것은 요청이므로 넘긴다.
        //
        // 넘기되 무엇을 넘기는지는 못 박는다. 종류를 안 보고 삼키면 응답을
        // 읽다 난 오류나 화면을 그리다 난 오류까지 함께 사라져, 그 뒤로는
        // 어떤 고장이 나도 이 시험이 통과한다. 지도가 안 열리는 그 하나만
        // 넘어가게 둔다.
        // 넘어간 화면은 이 환경에서 그려지지 않는다(지도 미초기화 등). 그것은
        // 넘기되, 무엇을 넘기는지는 못 박는다. 종류를 안 보고 삼키면 응답을
        // 읽다 난 오류까지 함께 사라져 — 위의 요청 검증은 응답이 오기 전에
        // 이미 끝나 있다 — 그 뒤로는 어떤 고장이 나도 이 시험이 통과한다.
        //
        // 한 프레임에 여러 건이 쌓이면 나중에 한꺼번에 꺼낼 때 "여러 건"이라는
        // 요약만 남아 내용을 볼 수 없으므로, 나는 자리에서 건건이 받아 둔다.
        final caught = <FlutterErrorDetails>[];
        final previousOnError = FlutterError.onError;
        FlutterError.onError = caught.add;
        await tester.pump(const Duration(seconds: 3));
        FlutterError.onError = previousOnError;

        // 화면을 그리다 난 것만 허용한다. 응답을 읽다 난 오류(형 불일치·널
        // 참조)나 서버 통신 오류가 섞였다면 그것은 이 시험이 지키려는 배선이
        // 깨진 것이다.
        for (final details in caught) {
          expect(
            details.library,
            anyOf(equals('widgets library'), equals('Flutter framework')),
            reason: '화면 렌더 말고 다른 층에서 난 오류는 회귀다: ${details.exception}',
          );
          expect(
            details.exception,
            isNot(anyOf(isA<ApiException>(), isA<TripApiException>())),
            reason: '요청·응답 경로에서 난 오류는 회귀다: ${details.exception}',
          );
          expect(
            details.exception,
            isNot(anyOf(isA<TypeError>(), isA<NoSuchMethodError>())),
            reason: '응답을 읽다 난 오류는 회귀다: ${details.exception}',
          );
        }
      },
      createHttpClient: (_) =>
          _FakeHttpClient(routeBody(), 200, requested, sentBodies),
    );
  });

  testWidgets('전송 동의를 거절하면 HTTP 0건이며 선택과 일정이 유지된다', (tester) async {
    await HttpOverrides.runZoned(() async {
      givenPlan([stop(order: 1, name: '가'), stop(order: 2, name: '나'), stop(order: 3, name: '다')]);
      final original = TripRepository.instance.lastPlan;
      final selected = {planPlaceId(0), planPlaceId(1), planPlaceId(2)};
      await pump(tester, selected);
      await tester.pumpAndSettle();
      await tester.tap(find.text('동의하지 않음'));
      await tester.pumpAndSettle();
      expect(requested, isEmpty);
      expect(sentBodies, isEmpty);
      expect(selected, {planPlaceId(0), planPlaceId(1), planPlaceId(2)});
      expect(TripRepository.instance.lastPlan, same(original));
      expect(find.byType(AppLoadingScreen), findsNothing);
      expect(find.text('동의 확인하고 일정 만들기'), findsOneWidget);
    }, createHttpClient: (_) => _FakeHttpClient(routeBody(), 200, requested, sentBodies));
  });

  testWidgets('손볼 일정이 없으면 요청하지 않고 안내한다', (tester) async {
    await HttpOverrides.runZoned(
      () async {
        await pump(tester, {planPlaceId(0), planPlaceId(1), planPlaceId(2)});
        await tester.pump(const Duration(milliseconds: 100));

        expect(requested, isEmpty);
        expect(find.textContaining('일정을 먼저 만들어 주세요'), findsOneWidget);
      },
      createHttpClient: (_) =>
          _FakeHttpClient(routeBody(), 200, requested, sentBodies),
    );
  });

  testWidgets('고른 곳이 적으면 요청하지 않고 안내한다', (tester) async {
    await HttpOverrides.runZoned(
      () async {
        givenPlan([
          stop(order: 1, name: '가'),
          stop(order: 2, name: '나'),
          stop(order: 3, name: '다'),
        ]);

        await pump(tester, {planPlaceId(0), planPlaceId(1)});
        await tester.pump(const Duration(milliseconds: 100));

        expect(requested, isEmpty);
        expect(find.textContaining('3곳 이상'), findsOneWidget);
      },
      createHttpClient: (_) =>
          _FakeHttpClient(routeBody(), 200, requested, sentBodies),
    );
  });

  testWidgets('서버가 받는 상한을 넘기면 요청하지 않고 안내한다', (tester) async {
    await HttpOverrides.runZoned(
      () async {
        givenPlan([
          for (int i = 0; i < 11; i++) stop(order: i + 1, name: '장소$i'),
        ]);

        await pump(tester, {for (int i = 0; i < 11; i++) planPlaceId(i)});
        await tester.pump(const Duration(milliseconds: 100));

        expect(requested, isEmpty);
        expect(find.textContaining('10곳까지만'), findsOneWidget);
      },
      createHttpClient: (_) =>
          _FakeHttpClient(routeBody(), 200, requested, sentBodies),
    );
  });

  testWidgets('일부를 빼면 뺀 자리를 새 장소로 채워 달라고 한다', (tester) async {
    await HttpOverrides.runZoned(
      () async {
        // 재탐색을 걸 수 있는 맥락 — 조건과 이전 추천 식별자가 함께 있다.
        TripRepository.instance.setLastPlan(TripPlanContext(
          startDate: DateTime(2026, 5, 1),
          endDate: DateTime(2026, 5, 1),
          activeStartHour: 9,
          activeEndHour: 20,
          transport: 'walk',
          province: '강원특별자치도',
          city: '속초시',
          stops: [
            TripStop(
                order: 1,
                name: '속초해변',
                address: '주소',
                time: '09:00',
                latitude: 38.19,
                longitude: 128.60,
                contentId: 'kakao:1'),
            TripStop(
                order: 2,
                name: '영금정',
                address: '주소',
                time: '10:00',
                latitude: 38.21,
                longitude: 128.60,
                contentId: 'kakao:2'),
            TripStop(
                order: 3,
                name: '중앙시장',
                address: '주소',
                time: '11:00',
                latitude: 38.20,
                longitude: 128.60,
                contentId: 'kakao:3'),
          ],
          tripId: 'job-prev',
          minBudget: 50000,
          maxBudget: 150000,
          themes: const ['food'],
        ));

        await pump(tester, {planPlaceId(0)});
        await acceptConsent(tester);
        await tester.pump(const Duration(milliseconds: 100));

        // 동선만 다시 짜는 자리가 아니라 새 장소를 받아 오는 자리로 간다.
        expect(requested.map((u) => u.path),
            contains(endsWith('/trip/research')));
        expect(requested.where((u) => u.path.endsWith('/trip/route')), isEmpty);
        expect(requested.where((u) => u.path.endsWith('/trip/research')), hasLength(1));

        final body = jsonDecode(sentBodies.single) as Map<String, dynamic>;
        expect(body['prev_trip_id'], 'job-prev');
        expect((body['keep'] as List).single, containsPair('name', '속초해변'));
        expect(body['exclude'], ['kakao:1', 'kakao:2', 'kakao:3']);

        await drainLoadingTimer(tester);
      },
      createHttpClient: (_) =>
          _FakeHttpClient(routeBody(), 200, requested, sentBodies),
    );
  });

  testWidgets('하나도 빼지 않으면 예전처럼 동선만 다시 짠다', (tester) async {
    await HttpOverrides.runZoned(
      () async {
        TripRepository.instance.setLastPlan(TripPlanContext(
          startDate: DateTime(2026, 5, 1),
          endDate: DateTime(2026, 5, 1),
          activeStartHour: 9,
          activeEndHour: 20,
          transport: 'walk',
          province: '강원특별자치도',
          city: '속초시',
          stops: [
            stop(order: 1, name: '가'),
            stop(order: 2, name: '나'),
            stop(order: 3, name: '다'),
          ],
          tripId: 'job-prev',
          minBudget: 50000,
          maxBudget: 150000,
          themes: const ['food'],
        ));

        await pump(tester, {planPlaceId(0), planPlaceId(1), planPlaceId(2)});
        await acceptConsent(tester);
        await tester.pump(const Duration(milliseconds: 100));

        expect(requested.map((u) => u.path), contains(endsWith('/trip/route')));
        expect(requested.where((u) => u.path.endsWith('/trip/route')), hasLength(1));
        expect(
            requested.where((u) => u.path.endsWith('/trip/research')), isEmpty);

        await drainLoadingTimer(tester);
      },
      createHttpClient: (_) =>
          _FakeHttpClient(routeBody(), 200, requested, sentBodies),
    );
  });
}

/// 통신을 대신 받아 미리 정한 본문을 돌려주는 대역.
class _FakeHttpClient implements HttpClient {
  _FakeHttpClient(this.body, this.status, this.requested, this.sentBodies);

  final String body;
  final int status;
  final List<Uri> requested;
  final List<String> sentBodies;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    requested.add(url);
    return _FakeRequest(url, body, status, sentBodies);
  }

  /// 대역이 쓰지 않는 나머지 요구는 조용히 흘려보낸다.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeRequest implements HttpClientRequest {
  _FakeRequest(this.uri, this.body, this.status, this.sentBodies);

  @override
  final Uri uri;
  final String body;
  final int status;
  final List<String> sentBodies;
  final _sent = <int>[];

  @override
  final HttpHeaders headers = _FakeHeaders();

  @override
  void add(List<int> data) => _sent.addAll(data);

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      _sent.addAll(chunk);
    }
  }

  @override
  Future<HttpClientResponse> close() async {
    if (_sent.isNotEmpty) sentBodies.add(utf8.decode(_sent));
    return _FakeResponse(body, status);
  }

  @override
  Future<HttpClientResponse> get done => close();

  /// 대역이 쓰지 않는 나머지 요구는 조용히 흘려보낸다.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  _FakeResponse(String body, this.statusCode) : _bytes = utf8.encode(body);

  final List<int> _bytes;

  @override
  final int statusCode;

  @override
  String get reasonPhrase => 'OK';

  @override
  int get contentLength => _bytes.length;

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  bool get persistentConnection => false;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  final HttpHeaders headers = _FakeHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.value(_bytes).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  /// 대역이 쓰지 않는 나머지 요구는 조용히 흘려보낸다.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHeaders implements HttpHeaders {
  final _values = <String, List<String>>{};

  @override
  List<String>? operator [](String name) => _values[name.toLowerCase()];

  @override
  String? value(String name) => _values[name.toLowerCase()]?.first;

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[name.toLowerCase()] = ['$value'];
  }

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _values.putIfAbsent(name.toLowerCase(), () => []).add('$value');
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _values.forEach(action);
  }

  @override
  int get contentLength => -1;

  @override
  ContentType? get contentType => null;

  /// 대역이 쓰지 않는 나머지 요구는 조용히 흘려보낸다.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
