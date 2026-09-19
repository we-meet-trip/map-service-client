import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/features/trip/screens/trip_directions_screen.dart';

void main() {
  test('서울은 시도명이 두 번 찍히지 않는다', () {
    // 실제로 화면에 '서울특별시 서울특별시 태평로1가 세종대로' 가 찍혔다.
    expect(
      joinAddressParts(['서울특별시', '서울특별시', '태평로1가', '세종대로']),
      '서울특별시 태평로1가 세종대로',
    );
  });

  test('시도명과 시군구가 다르면 둘 다 남는다', () {
    expect(
      joinAddressParts(['부산광역시', '해운대구', '우동', '해운대해변로']),
      '부산광역시 해운대구 우동 해운대해변로',
    );
  });

  test('떨어져 있는 같은 이름은 지우지 않는다', () {
    // 붙어 있는 중복만 걷어낸다. 전부 지우면 이런 주소가 뭉개진다.
    expect(
      joinAddressParts(['경기도', '광주시', '광주', '역동']),
      '경기도 광주시 광주 역동',
    );
  });

  test('빈 조각과 null 은 건너뛴다', () {
    expect(joinAddressParts(['서울특별시', null, '', '중구']), '서울특별시 중구');
    expect(joinAddressParts([null, '']), '');
  });
}
