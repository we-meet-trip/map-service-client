import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/naver_map/naver_map_bootstrap.dart';

/// 지도 식별자를 쓸 순서를 고정한다.
///
/// 값이 두 곳에 서로 다르게 들어 있던 적이 있고, 어느 쪽이 맞는지는 화면을
/// 열어 보기 전까지 드러나지 않는다. 그래서 하나를 고르는 대신 순서를 두기로
/// 했다 — 그 순서가 뒤집히면 잘못된 값으로 먼저 붙게 되므로 여기서 못박는다.
void main() {
  group('resolveNaverMapClientIds', () {
    test('앞의 것이 1순위, 예비가 2순위다', () {
      final got = resolveNaverMapClientIds({
        'NAVER_MAP_CLIENT_ID': 'primary',
        'NAVER_MAP_CLIENT_ID_FALLBACK': 'secondary',
      });
      expect(got, ['primary', 'secondary']);
    });

    test('두 자리가 같은 값이면 한 번만 시도한다', () {
      final got = resolveNaverMapClientIds({
        'NAVER_MAP_CLIENT_ID': 'same',
        'NAVER_MAP_CLIENT_ID_FALLBACK': 'same',
      });
      expect(got, ['same']);
    });

    test('예비가 없으면 하나만 쓴다', () {
      final got = resolveNaverMapClientIds({'NAVER_MAP_CLIENT_ID': 'only'});
      expect(got, ['only']);
    });

    test('1순위가 비어 있으면 예비가 앞으로 온다', () {
      final got = resolveNaverMapClientIds({
        'NAVER_MAP_CLIENT_ID': '',
        'NAVER_MAP_CLIENT_ID_FALLBACK': 'secondary',
      });
      expect(got, ['secondary']);
    });

    test('앞뒤 공백은 걷어내고, 공백뿐인 값은 버린다', () {
      final got = resolveNaverMapClientIds({
        'NAVER_MAP_CLIENT_ID': '  primary  ',
        'NAVER_MAP_CLIENT_ID_FALLBACK': '   ',
      });
      expect(got, ['primary']);
    });

    test('둘 다 없으면 비어 있다', () {
      expect(resolveNaverMapClientIds(const {}), isEmpty);
    });
  });
}
