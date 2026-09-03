// 사진 응답을 화면이 쓰는 형태로 옮기는 과정에서 걸러 내야 할 것들을 본다.
//
// 서버는 사진 목록을 통째로 주고, 그중 화면에 걸 수 없는 항목이 섞여 올 수
// 있다. 주소가 없으면 이미지를 못 띄우고, 이름이 없는 표기는 제공자를 밝히지
// 못한다. 이런 항목이 남으면 빈 타일이나 이름 없는 표기가 화면에 나간다.
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/api/place_photo_api_service.dart';

void main() {
  group('PlacePhoto.fromJson', () {
    test('서버가 준 값을 그대로 옮긴다', () {
      final photo = PlacePhoto.fromJson({
        'photo_uri': 'https://lh3.example/img=w800',
        'width_px': 1600,
        'height_px': 1200,
        'attributions': [
          {'display_name': '홍길동', 'uri': 'https://maps.example/u/1'},
        ],
        'google_maps_uri': 'https://maps.example/p/1',
        'flag_content_uri': 'https://maps.example/f/1',
      });

      expect(photo.photoUri, 'https://lh3.example/img=w800');
      expect(photo.widthPx, 1600);
      expect(photo.heightPx, 1200);
      expect(photo.googleMapsUri, 'https://maps.example/p/1');
      expect(photo.attributions, hasLength(1));
      expect(photo.attributions.first.displayName, '홍길동');
      expect(photo.attributions.first.uri, 'https://maps.example/u/1');
    });

    test('이름 없는 표기는 버린다 — 제공자를 밝히지 못하는 표기다', () {
      final photo = PlacePhoto.fromJson({
        'photo_uri': 'https://lh3.example/a',
        'attributions': [
          {'display_name': '', 'uri': 'https://maps.example/u/1'},
          {'uri': 'https://maps.example/u/2'},
          {'display_name': '김철수'},
        ],
      });

      expect(photo.attributions, hasLength(1));
      expect(photo.attributions.first.displayName, '김철수');
      expect(photo.attributions.first.uri, isNull);
    });

    test('크기와 표기가 없어도 열린다', () {
      final photo = PlacePhoto.fromJson({'photo_uri': 'https://lh3.example/b'});

      expect(photo.photoUri, 'https://lh3.example/b');
      expect(photo.widthPx, isNull);
      expect(photo.heightPx, isNull);
      expect(photo.attributions, isEmpty);
      expect(photo.googleMapsUri, isNull);
    });

    test('표기가 목록이 아닌 값으로 와도 빈 목록으로 다룬다', () {
      final photo = PlacePhoto.fromJson({
        'photo_uri': 'https://lh3.example/c',
        'attributions': 'not-a-list',
      });

      expect(photo.attributions, isEmpty);
    });

    test('크기가 실수로 와도 정수로 옮긴다', () {
      final photo = PlacePhoto.fromJson({
        'photo_uri': 'https://lh3.example/d',
        'width_px': 800.0,
        'height_px': 600.0,
      });

      expect(photo.widthPx, 800);
      expect(photo.heightPx, 600);
    });

    test('주소가 없으면 빈 문자열이 되어 호출 측이 걸러 낼 수 있다', () {
      final photo = PlacePhoto.fromJson({'width_px': 100});

      expect(photo.photoUri, isEmpty);
    });
  });
}
