import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:map_service_client/common/widgets/place_photo_strip.dart';
import 'package:map_service_client/features/place_explore/models/place_detail.dart';
import 'package:map_service_client/features/place_explore/widgets/place_bottom_sheet.dart';

/// 장소 상세가 네 가지 사정을 화면에서 갈라 말하는지 본다.
///
/// 조회가 실패한 것과 자료가 원래 없는 것은 다른 사정인데, 예전에는 둘 다
/// 같은 문구로 덮였다. 그래서 서버가 통째로 멈춰 있어도 화면·검사 어느 쪽도
/// 그것을 알아채지 못했다.
///
/// 사진 쪽은 한 장만 왔을 때를 따로 본다. 큰 사진과 아래 목록이 한 덩어리로
/// 걸리는데 표기를 목록에만 달아 두면, 한 장뿐이라 목록이 접히는 순간 사진은
/// 걸린 채 출처만 사라진다.
void main() {
  const detail = PlaceDetail(
    id: 'stop_0',
    name: '소양강스카이워크',
    address: '강원특별자치도 춘천시 근화동 8-1',
    category: '여행 / 관광,명소 / 전망대',
  );

  http.Response jsonBody(Object body, {int status = 200}) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  /// 통신만 가짜로 바꿔 실제 조회 절차를 그대로 태운다.
  Future<void> pump(
    WidgetTester tester,
    Future<http.Response> Function(http.Request request) handler, {
    bool withCoordinates = true,
  }) {
    return http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaceBottomSheet(
              detail: detail,
              latitude: withCoordinates ? 37.9424 : null,
              longitude: withCoordinates ? 127.7250 : null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }, () => MockClient(handler));
  }

  Future<void> dragSheetUp(WidgetTester tester) async {
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await tester.pumpAndSettle();
  }

  Map<String, Object?> photo(String uri) => {
    'photo_uri': uri,
    'width_px': 1600,
    'height_px': 1200,
    'attributions': [
      {'display_name': '서정미', 'uri': 'https://maps.google.com/u'},
    ],
    'google_maps_uri': 'https://maps.google.com/p',
  };

  testWidgets('후기가 정말 0건이면 없다고 말한다', (tester) async {
    await pump(tester, (request) async {
      if (request.url.path == '/api/v1/reviews') {
        return jsonBody({'query': '소양강스카이워크', 'reviews': [], 'count': 0});
      }
      return jsonBody({'photos': []});
    });
    await dragSheetUp(tester);

    expect(find.text('아직 등록된 후기가 없어요.'), findsOneWidget);
    expect(find.text('후기를 불러오지 못했어요.'), findsNothing);
  });

  testWidgets('후기 조회가 실패하면 없다고 말하지 않는다', (tester) async {
    await pump(tester, (request) async {
      if (request.url.path == '/api/v1/reviews') {
        return jsonBody({'code': 'review_search_upstream_error'}, status: 502);
      }
      return jsonBody({'photos': []});
    });
    await dragSheetUp(tester);

    expect(find.text('후기를 불러오지 못했어요.'), findsOneWidget);
    expect(find.text('아직 등록된 후기가 없어요.'), findsNothing);
    // 다시 청할 길을 남긴다 — 실패했다고만 적어 두면 막다른 길이다.
    expect(find.text('다시 시도'), findsOneWidget);
  });

  testWidgets('사진이 한 장뿐이어도 출처 표기가 남는다', (tester) async {
    await pump(tester, (request) async {
      if (request.url.path == '/api/v1/places/photos') {
        return jsonBody({
          'photos': [photo('https://example.invalid/a.jpg')],
        });
      }
      return jsonBody({'query': '소양강스카이워크', 'reviews': [], 'count': 0});
    });

    // 사진이 화면까지 흘러왔는지는 큰 사진 자리에 그림이 걸렸는지로 본다.
    // PlacePhotoHero 가 트리에 있는지만 보면 사진이 0장이어도 통과한다.
    expect(find.byType(PlacePhotoHero), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    expect(find.text('제공: Google'), findsOneWidget);
  });

  testWidgets('사진이 여러 장이어도 출처 표기는 한 번만 단다', (tester) async {
    await pump(tester, (request) async {
      if (request.url.path == '/api/v1/places/photos') {
        return jsonBody({
          'photos': [
            photo('https://example.invalid/a.jpg'),
            photo('https://example.invalid/b.jpg'),
            photo('https://example.invalid/c.jpg'),
          ],
        });
      }
      return jsonBody({'query': '소양강스카이워크', 'reviews': [], 'count': 0});
    });

    expect(find.text('제공: Google'), findsOneWidget);

    // 남은 사진 목록은 시트 아래쪽에 있어 끌어올려야 그려진다.
    await dragSheetUp(tester);
    expect(find.byType(PlacePhotoStrip), findsOneWidget);
  });

  testWidgets('사진이 없는 장소에는 빈 회색 칸을 남기지 않는다', (tester) async {
    await pump(tester, (request) async {
      if (request.url.path == '/api/v1/places/photos') {
        return jsonBody({'photos': []});
      }
      return jsonBody({'query': '소양강스카이워크', 'reviews': [], 'count': 0});
    });

    expect(find.byType(PlacePhotoHero), findsNothing);
    expect(find.text('제공: Google'), findsNothing);
    expect(find.text('사진을 불러오지 못했어요.'), findsNothing);
  });

  testWidgets('사진 조회가 실패하면 없는 것과 갈라 말한다', (tester) async {
    await pump(tester, (request) async {
      if (request.url.path == '/api/v1/places/photos') {
        return jsonBody({'code': 'place_photos_upstream_error'}, status: 502);
      }
      return jsonBody({'query': '소양강스카이워크', 'reviews': [], 'count': 0});
    });

    expect(find.text('사진을 불러오지 못했어요.'), findsOneWidget);
    expect(find.byType(PlacePhotoHero), findsNothing);
  });
}
