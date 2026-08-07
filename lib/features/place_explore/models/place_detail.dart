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
  final String category;
  final double rating;
  final String openingHours;
  final String aiSummary;
  final List<BlogReview> blogReviews;

  const PlaceDetail({
    required this.id,
    required this.name,
    required this.address,
    required this.category,
    required this.rating,
    required this.openingHours,
    required this.aiSummary,
    required this.blogReviews,
  });
}
