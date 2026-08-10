/// 처음 보여 주는 후기 수.
const kFirstReviewPageSize = 2;

/// 한 번에 채우는 후기 수. 첫 더보기는 앞의 2건에 3건을 더해 5건을 만들고,
/// 그 뒤로는 5건씩 늘어난다.
const kMoreReviewPageSize = 5;

/// 다음에 받아올 후기 구간.
class ReviewPage {
  /// 서버에 보낼 시작 위치. 1부터 센다.
  final int start;

  /// 이번에 받을 개수.
  final int display;

  const ReviewPage({required this.start, required this.display});

  @override
  bool operator ==(Object other) =>
      other is ReviewPage && other.start == start && other.display == display;

  @override
  int get hashCode => Object.hash(start, display);

  @override
  String toString() => 'ReviewPage(start: $start, display: $display)';
}

/// 지금까지 받은 개수를 보고 다음 구간을 정한다.
///
/// 아직 없으면 2건, 5건에 못 미치면 5건이 되도록 모자란 만큼, 그 뒤로는
/// 5건씩 받는다.
ReviewPage nextReviewPage(int loadedCount) {
  if (loadedCount <= 0) {
    return const ReviewPage(start: 1, display: kFirstReviewPageSize);
  }
  final display = loadedCount < kMoreReviewPageSize
      ? kMoreReviewPageSize - loadedCount
      : kMoreReviewPageSize;
  return ReviewPage(start: loadedCount + 1, display: display);
}
