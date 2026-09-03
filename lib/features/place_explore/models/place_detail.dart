class BlogReview {
  final String title;
  final String blogName;
  final String date;
  final String snippet;
  final String url;

  const BlogReview({
    required this.title,
    required this.blogName,
    required this.date,
    required this.snippet,
    this.url = '',
  });
}

class PlaceDetail {
  final String id;
  final String name;
  final String address;

  /// 장소 분류. 분류가 없는 장소는 칩을 그리지 않는다.
  final String? category;

  final double rating;
  final String openingHours;

  /// 후기를 종합한 요약과 그 근거가 된 후기 목록. 일정의 장소로 조립한
  /// 상세에는 비어 있다.
  final String aiSummary;
  final List<BlogReview> blogReviews;

  const PlaceDetail({
    required this.id,
    required this.name,
    required this.address,
    this.category,
    this.rating = 0,
    this.openingHours = '',
    this.aiSummary = '',
    this.blogReviews = const [],
  });
}
