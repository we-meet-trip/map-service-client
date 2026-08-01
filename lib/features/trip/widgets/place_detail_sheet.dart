import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../common/theme/app_colors.dart';
import '../../../core/api/review_api_service.dart';

/// 장소 상세를 아래에서 올라오는 시트로 보여 준다.
///
/// [name] 은 장소명, [address] 는 주소, [category] 는 분류 칩에 쓴다.
/// [initialBullets] 는 일정을 만들 때 이미 받아 둔 두 줄 요약이다. 값이 있으면
/// 그대로 쓰고, 없을 때만 서버에 새로 물어 본다 — 같은 요약을 두 번 만들 이유가
/// 없다.
///
/// 별점·사진·영업시간은 화면에 두지 않는다. 지금 쓰는 장소 출처가 그 값을 주지
/// 않아서, 자리를 만들어 두면 늘 비어 있는 칸이 남는다.
Future<void> showPlaceDetailSheet(
  BuildContext context, {
  required String name,
  required String address,
  String? category,
  List<String> initialBullets = const [],
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PlaceDetailSheet(
      name: name,
      address: address,
      category: category,
      initialBullets: initialBullets,
    ),
  );
}

class _PlaceDetailSheet extends StatefulWidget {
  const _PlaceDetailSheet({
    required this.name,
    required this.address,
    required this.category,
    required this.initialBullets,
  });

  final String name;
  final String address;
  final String? category;
  final List<String> initialBullets;

  @override
  State<_PlaceDetailSheet> createState() => _PlaceDetailSheetState();
}

class _PlaceDetailSheetState extends State<_PlaceDetailSheet> {
  /// 처음 보여 주는 후기 수.
  static const _firstPageSize = 2;

  /// 더보기를 누를 때마다 늘리는 수. 첫 더보기에서 앞의 2건에 3건을 더해 5건이
  /// 되고, 그 뒤로는 5건씩 늘어난다.
  static const _morePageSize = 5;

  final _api = ReviewApiService.instance;

  List<String> _bullets = const [];
  bool _summaryLoading = false;

  final List<BlogReview> _reviews = [];
  bool _reviewsLoading = true;
  bool _moreLoading = false;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    _bullets = widget.initialBullets;
    if (_bullets.isEmpty) {
      _loadSummary();
    }
    _loadFirstPage();
  }

  Future<void> _loadSummary() async {
    setState(() => _summaryLoading = true);
    final bullets = await _api.fetchSummary(widget.name);
    if (!mounted) return;
    setState(() {
      _bullets = bullets;
      _summaryLoading = false;
    });
  }

  Future<void> _loadFirstPage() async {
    final page = await _api.fetchReviews(
      widget.name,
      start: 1,
      display: _firstPageSize,
    );
    if (!mounted) return;
    setState(() {
      _reviews
        ..clear()
        ..addAll(page.reviews);
      _hasMore = page.hasMore;
      _reviewsLoading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_moreLoading) return;
    setState(() => _moreLoading = true);
    // 첫 더보기는 5건까지 채우고, 그 뒤로는 5건씩 더 받는다.
    final target = _reviews.length < _morePageSize
        ? _morePageSize - _reviews.length
        : _morePageSize;
    final page = await _api.fetchReviews(
      widget.name,
      start: _reviews.length + 1,
      display: target,
    );
    if (!mounted) return;
    setState(() {
      _reviews.addAll(page.reviews);
      _hasMore = page.hasMore;
      _moreLoading = false;
    });
  }

  Future<void> _openLink(String link) async {
    if (link.isEmpty) return;
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.neutralScale[100],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.name,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700),
            ),
            if (widget.address.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                widget.address,
                style: TextStyle(
                    fontSize: 13, color: AppColors.neutralScale[400]),
              ),
            ],
            if (widget.category != null && widget.category!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryScale[50],
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    widget.category!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryScale[500],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            _buildSummary(),
            const SizedBox(height: 24),
            _buildReviews(),
          ],
        ),
      ),
    );
  }

  /// 요약 영역. 근거를 못 구했으면 영역째 접는다.
  Widget _buildSummary() {
    if (_summaryLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_bullets.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome,
                size: 18, color: AppColors.primaryScale[400]),
            const SizedBox(width: 6),
            const Text('AI 리뷰 요약',
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryScale[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primaryScale[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in _bullets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    line,
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.neutralScale[600]),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 블로그 후기 목록과 더보기.
  Widget _buildReviews() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('블로그 리뷰',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        if (_reviewsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text('아직 등록된 후기가 없어요.',
                style: TextStyle(
                    fontSize: 13, color: AppColors.neutralScale[300])),
          )
        else
          for (final review in _reviews) _ReviewCard(
            review: review,
            onTap: () => _openLink(review.link),
          ),
        if (_hasMore && !_reviewsLoading) ...[
          const SizedBox(height: 4),
          Center(
            child: TextButton.icon(
              onPressed: _moreLoading ? null : _loadMore,
              icon: _moreLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              label: const Text('블로그 리뷰 더보기'),
            ),
          ),
        ],
      ],
    );
  }
}

/// 후기 한 건. 누르면 원문으로 이동한다.
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.onTap});

  final BlogReview review;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      review.bloggerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (review.title.isNotEmpty) ...[
                    Text('  |  ',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.neutralScale[200])),
                    Expanded(
                      flex: 2,
                      child: Text(
                        review.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                review.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.neutralScale[500]),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(review.displayDate,
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.neutralScale[300])),
                  Row(
                    children: [
                      Text('더보기',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryScale[500])),
                      Icon(Icons.arrow_forward_rounded,
                          size: 14, color: AppColors.primaryScale[500]),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
