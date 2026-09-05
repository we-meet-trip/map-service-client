import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/api/places_api_service.dart';

/// 장소 검색 결과 해석 검증.
///
/// 출처마다 채워지는 값이 달라 빠진 키가 흔하다. 하나가 비었다고 목록
/// 전체가 열리지 않으면 안 되고, 일정에 넣을 수 없는 항목은 버려야 한다.
void main() {
  test('도로명이 있으면 그쪽을 보여 준다', () {
    final item = PlaceSearchItem.tryFromJson({
      'content_id': 'kakao:1',
      'name': '성수동 카페',
      'address': '서울 성동구 성수동',
      'road_address': '서울 성동구 연무장길 1',
      'lat': 37.54,
      'lng': 127.05,
      'category': '음식점 > 카페',
      'place_url': 'http://place/1',
    })!;

    expect(item.contentId, 'kakao:1');
    expect(item.displayAddress, '서울 성동구 연무장길 1');
    expect(item.category, '음식점 > 카페');
  });

  test('도로명이 없으면 지번 주소를 보여 준다', () {
    final item = PlaceSearchItem.tryFromJson({
      'name': '이름만 있는 곳',
      'address': '서울 종로구 청운동 1',
      'lat': 37.5,
      'lng': 127.0,
    })!;

    expect(item.displayAddress, '서울 종로구 청운동 1');
    expect(item.contentId, isEmpty);
    expect(item.category, isNull);
  });

  test('좌표나 이름이 없으면 일정에 넣을 수 없어 버린다', () {
    expect(
        PlaceSearchItem.tryFromJson(
            {'name': '좌표 없음', 'address': '주소'}),
        isNull);
    expect(
        PlaceSearchItem.tryFromJson(
            {'address': '주소', 'lat': 37.5, 'lng': 127.0}),
        isNull);
  });
}
