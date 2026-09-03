import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/features/place_explore/utils/review_paging.dart';

/// 후기 더보기 구간 계산 검증.
///
/// 처음 2건, 첫 더보기에서 5건이 되도록 3건, 그 뒤로는 5건씩이라는 규칙을
/// 지켜야 한다. 서버가 받는 개수는 1~10 사이여야 한다.
void main() {
  test('처음에는 2건을 받는다', () {
    expect(nextReviewPage(0), const ReviewPage(start: 1, display: 2));
  });

  test('첫 더보기는 5건이 되도록 모자란 만큼만 받는다', () {
    expect(nextReviewPage(2), const ReviewPage(start: 3, display: 3));
  });

  test('5건을 채운 뒤로는 5건씩 받는다', () {
    expect(nextReviewPage(5), const ReviewPage(start: 6, display: 5));
    expect(nextReviewPage(10), const ReviewPage(start: 11, display: 5));
    expect(nextReviewPage(15), const ReviewPage(start: 16, display: 5));
  });

  test('중간에 덜 받은 경우에도 5건까지만 채운다', () {
    expect(nextReviewPage(1), const ReviewPage(start: 2, display: 4));
    expect(nextReviewPage(4), const ReviewPage(start: 5, display: 1));
  });

  test('받을 개수가 서버가 허용하는 범위 안이다', () {
    for (var loaded = 0; loaded <= 30; loaded++) {
      final page = nextReviewPage(loaded);
      expect(page.display, greaterThanOrEqualTo(1));
      expect(page.display, lessThanOrEqualTo(10));
      expect(page.start, greaterThanOrEqualTo(1));
    }
  });

  test('시작 위치는 앞 구간 다음 자리를 가리킨다', () {
    var loaded = 0;
    final page1 = nextReviewPage(loaded);
    loaded += page1.display;
    final page2 = nextReviewPage(loaded);
    loaded += page2.display;
    final page3 = nextReviewPage(loaded);

    expect(page1.start, 1);
    expect(page2.start, 3);
    expect(page3.start, 6);
    expect(loaded, 5);
  });
}
