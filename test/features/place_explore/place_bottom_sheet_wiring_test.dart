import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/features/place_explore/models/place_detail.dart';
import 'package:map_service_client/features/place_explore/widgets/place_bottom_sheet.dart';

/// 장소 팝업이 서버가 준 요약·후기를 그대로 그리는지 검증.
///
/// 아래 응답 본문은 로컬 스택의 `/api/v1/reviews`, `/api/v1/reviews/summary` 가
/// 실제로 돌려준 모양이다. 통신만 대신 받아 두고 화면까지 값이 흐르는지 본다.
void main() {
  /// 요청 주소별로 돌려줄 본문.
  String bodyFor(Uri uri) {
    if (uri.path.endsWith('/reviews/summary')) {
      return jsonEncode({
        'query': '속초해변',
        'bullets': [
          '속초해변은 우동당에서 식사 후 산책하기 좋으며, 젤라또를 즐길 수 있습니다.',
          '속초해변에는 동전 샤워장이 남문 주차장 옆과 북문 쪽에 마련되어 있습니다.',
        ],
        'sourceCount': 7,
      });
    }
    final start = int.parse(uri.queryParameters['start']!);
    final display = int.parse(uri.queryParameters['display']!);
    return jsonEncode({
      'query': '속초해변',
      'start': start,
      'count': display,
      'reviews': [
        for (var i = 0; i < display; i++)
          {
            'title': '속초 여행기 ${start + i}',
            'description': '속초해변 다녀온 기록 ${start + i}',
            'bloggername': '블로거${start + i}',
            'postdate': '2026080${(start + i) % 9 + 1}',
            'link': 'https://blog.naver.com/sample/${start + i}',
          },
      ],
    });
  }

  final requested = <Uri>[];

  Future<void> pumpSheet(WidgetTester tester) async {
    // 후기 카드가 여러 장 붙는 화면이라, 좁은 창이면 아래쪽이 그려지지 않아
    // 찾지 못한다. 한 번에 다 담기는 창을 쓴다.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlaceBottomSheet(
            detail: PlaceDetail(
              id: 'stop_0',
              name: '속초해변',
              address: '강원특별자치도 속초시 청호동 해오름로 186',
              category: '여행 / 관광,명소 / 해수욕장,해변',
            ),
            isAdded: false,
            onToggle: _noop,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await tester.pumpAndSettle();
  }

  Future<void> tapMore(WidgetTester tester) async {
    await tester.tap(find.text('블로그 리뷰 더보기'));
    await tester.pumpAndSettle();
  }

  setUp(requested.clear);

  testWidgets('요약 두 줄과 첫 후기 두 건을 서버에서 받아 그린다', (tester) async {
    await HttpOverrides.runZoned(
      () async {
        await pumpSheet(tester);

        expect(find.text('AI 리뷰 요약'), findsOneWidget);
        expect(
          find.textContaining('동전 샤워장이 남문 주차장 옆'),
          findsOneWidget,
        );
        expect(find.text('블로거1'), findsOneWidget);
        expect(find.text('블로거2'), findsOneWidget);
        expect(find.text('블로거3'), findsNothing);
        expect(find.text('블로그 리뷰 더보기'), findsOneWidget);

        final reviewCalls =
            requested.where((u) => u.path.endsWith('/reviews')).toList();
        expect(reviewCalls, hasLength(1));
        expect(reviewCalls.single.queryParameters['start'], '1');
        expect(reviewCalls.single.queryParameters['display'], '2');
        expect(reviewCalls.single.queryParameters['sort'], 'date');
        expect(reviewCalls.single.queryParameters['query'], '속초해변');
      },
      createHttpClient: (_) => _FakeHttpClient(bodyFor, requested),
    );
  });

  testWidgets('더보기를 누르면 다섯 건이 되고 다시 누르면 열 건이 된다', (tester) async {
    await HttpOverrides.runZoned(
      () async {
        await pumpSheet(tester);

        await tapMore(tester);
        for (final name in ['블로거1', '블로거3', '블로거5']) {
          expect(find.text(name), findsOneWidget, reason: '$name 이 없다');
        }
        expect(find.text('블로거6'), findsNothing);

        await tapMore(tester);
        expect(find.text('블로거10'), findsOneWidget);
        expect(find.text('블로거11'), findsNothing);

        final pages = requested
            .where((u) => u.path.endsWith('/reviews'))
            .map((u) =>
                '${u.queryParameters['start']}/${u.queryParameters['display']}')
            .toList();
        expect(pages, ['1/2', '3/3', '6/5']);
      },
      createHttpClient: (_) => _FakeHttpClient(bodyFor, requested),
    );
  });

  testWidgets('분류는 화면이 쓰는 관심사 이름으로 바뀌어 붙는다', (tester) async {
    await HttpOverrides.runZoned(
      () async {
        await pumpSheet(tester);

        expect(find.text('해변'), findsOneWidget);
      },
      createHttpClient: (_) => _FakeHttpClient(bodyFor, requested),
    );
  });
}

void _noop() {}

/// 통신을 대신 받아 미리 정한 본문을 돌려주는 대역.
class _FakeHttpClient implements HttpClient {
  _FakeHttpClient(this.bodyFor, this.requested);

  final String Function(Uri uri) bodyFor;
  final List<Uri> requested;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    requested.add(url);
    return _FakeRequest(url, bodyFor(url));
  }

  /// 대역이 쓰지 않는 나머지 요구는 조용히 흘려보낸다.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeRequest implements HttpClientRequest {
  _FakeRequest(this.uri, this.body);

  @override
  final Uri uri;
  final String body;

  @override
  final HttpHeaders headers = _FakeHeaders();

  /// 보낼 본문은 쓰지 않지만, 통로가 이 자리를 기다리므로 받아만 둔다.
  @override
  Future<void> addStream(Stream<List<int>> stream) async {}

  @override
  Future<HttpClientResponse> close() async => _FakeResponse(body);

  @override
  Future<HttpClientResponse> get done async => close();

  /// 대역이 쓰지 않는 나머지 요구는 조용히 흘려보낸다.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  _FakeResponse(String body) : _bytes = utf8.encode(body);

  final List<int> _bytes;

  @override
  int get statusCode => 200;

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
