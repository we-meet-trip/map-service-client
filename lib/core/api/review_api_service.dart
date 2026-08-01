import 'dart:convert';

import 'package:http/http.dart' as http;

/// 블로그 후기 한 건.
class BlogReview {
  /// 블로그 이름.
  final String bloggerName;

  /// 글 제목.
  final String title;

  /// 본문 발췌. 화면에서 두 줄까지만 보여 준다.
  final String description;

  /// 작성일("YYYYMMDD"). 형식이 어긋나면 비어 있다.
  final String postDate;

  /// 원문 주소. 눌렀을 때 이 주소로 이동한다.
  final String link;

  const BlogReview({
    required this.bloggerName,
    required this.title,
    required this.description,
    required this.postDate,
    required this.link,
  });

  factory BlogReview.fromJson(Map<String, dynamic> json) => BlogReview(
        bloggerName: json['bloggername'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        postDate: json['postdate'] as String? ?? '',
        link: json['link'] as String? ?? '',
      );

  /// 화면에 쓰는 날짜 표기. 서버가 주는 8자리를 점으로 끊어 준다.
  String get displayDate {
    if (postDate.length != 8) return postDate;
    return '${postDate.substring(0, 4)}.'
        '${postDate.substring(4, 6)}.'
        '${postDate.substring(6, 8)}';
  }
}

/// 한 번에 받아 온 후기 묶음.
class BlogReviewPage {
  final List<BlogReview> reviews;

  /// 요청한 개수보다 적게 왔으면 이 구간이 마지막이다. 총 건수를 따로 받지
  /// 않는 이유는 외부가 주는 총계가 실제로 받을 수 있는 건수와 어긋나기
  /// 때문이다.
  final bool hasMore;

  const BlogReviewPage({required this.reviews, required this.hasMore});
}

/// 장소 상세의 블로그 후기와 요약을 가져오는 통로.
class ReviewApiService {
  ReviewApiService._();

  static final ReviewApiService instance = ReviewApiService._();

  static const _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  static const _timeout = Duration(seconds: 15);

  /// 후기를 구간 단위로 받는다.
  ///
  /// query: 장소명.
  /// start: 시작 위치(1부터). 더보기를 누를 때마다 앞 구간 길이를 더해 보낸다.
  /// display: 이번에 받을 개수.
  ///
  /// 조회에 실패하면 빈 묶음을 돌려준다 — 후기가 없다고 장소 상세를 못 그리는
  /// 것은 아니다.
  Future<BlogReviewPage> fetchReviews(
    String query, {
    required int start,
    required int display,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/reviews').replace(
      queryParameters: {
        'query': query,
        'start': '$start',
        'display': '$display',
        // 장소 상세 목록은 최신 글부터 보여 준다.
        'sort': 'date',
      },
    );
    try {
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        return const BlogReviewPage(reviews: [], hasMore: false);
      }
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final raw = body['reviews'];
      final items = raw is List
          ? raw
              .whereType<Map<String, dynamic>>()
              .map(BlogReview.fromJson)
              .toList()
          : <BlogReview>[];
      return BlogReviewPage(
        reviews: items,
        hasMore: items.length >= display,
      );
    } catch (_) {
      return const BlogReviewPage(reviews: [], hasMore: false);
    }
  }

  /// 장소의 두 줄 요약을 받는다.
  ///
  /// 근거가 부족하거나 요약에 실패하면 빈 목록이 온다. 그 자체는 오류가 아니며
  /// 화면은 요약 영역만 접는다.
  Future<List<String>> fetchSummary(String query) async {
    final uri = Uri.parse('$_baseUrl/api/v1/reviews/summary')
        .replace(queryParameters: {'query': query});
    try {
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) return const [];
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final raw = body['bullets'];
      if (raw is! List) return const [];
      return raw.whereType<String>().where((s) => s.trim().isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
  }
}
