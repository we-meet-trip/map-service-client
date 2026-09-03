import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../common/constants/category_tags.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/place_photo_strip.dart';
import '../../../core/api/place_photo_api_service.dart';
// 후기 모델 이름이 화면 모델과 겹쳐 통로 쪽에 이름을 붙여 구분한다.
import '../../../core/api/review_api_service.dart' as review_api;
import '../models/place_detail.dart';
import '../utils/review_paging.dart';
import 'blog_review_card.dart';
import 'place_ai_summary_card.dart';


class PlaceBottomSheet extends StatefulWidget {
  final PlaceDetail detail;
  final bool isAdded;
  final VoidCallback onToggle;

  /// 사진을 찾을 좌표. 같은 상호가 여러 지역에 있어 이름만으로 물으면 다른
  /// 동네 지점 사진이 온다. 좌표가 없으면 사진을 아예 청하지 않는다.
  final double? latitude;
  final double? longitude;

  const PlaceBottomSheet({
    super.key,
    required this.detail,
    required this.isAdded,
    required this.onToggle,
    this.latitude,
    this.longitude,
  });

  @override
  State<PlaceBottomSheet> createState() => _PlaceBottomSheetState();
}

class _PlaceBottomSheetState extends State<PlaceBottomSheet> {
  final _api = review_api.ReviewApiService.instance;
  final _photoApi = PlacePhotoApiService.instance;

  late bool _isAdded;

  List<String> _bullets = const [];
  bool _summaryLoading = false;

  List<PlacePhoto> _photos = const [];

  final List<BlogReview> _reviews = [];
  bool _reviewsLoading = true;
  bool _moreLoading = false;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    _isAdded = widget.isAdded;
    // 요약·후기·사진은 장소명으로 물어본다. 시트는 기다리지 않고 먼저 열리고
    // 받아온 뒤에 그 자리만 채워진다.
    _loadSummary();
    _loadFirstPage();
    _loadPhotos();
  }

  /// 사진을 받아 온다. 좌표가 없으면 아예 요청하지 않는다 — 이름만으로 찾은
  /// 사진은 다른 동네 지점의 것일 수 있고, 서버 쪽 조회에도 비용이 든다.
  Future<void> _loadPhotos() async {
    final lat = widget.latitude;
    final lng = widget.longitude;
    if (lat == null || lng == null) return;
    final photos = await _photoApi.fetchPhotos(
      widget.detail.name,
      latitude: lat,
      longitude: lng,
    );
    if (!mounted || photos.isEmpty) return;
    setState(() => _photos = photos);
  }

  void _handleToggle() {
    setState(() => _isAdded = !_isAdded);
    widget.onToggle();
  }

  Future<void> _loadSummary() async {
    setState(() => _summaryLoading = true);
    final bullets = await _api.fetchSummary(widget.detail.name);
    if (!mounted) return;
    setState(() {
      _bullets = bullets;
      _summaryLoading = false;
    });
  }

  Future<void> _loadFirstPage() async {
    final page = nextReviewPage(0);
    final result = await _api.fetchReviews(
      widget.detail.name,
      start: page.start,
      display: page.display,
    );
    if (!mounted) return;
    setState(() {
      _reviews
        ..clear()
        ..addAll(result.reviews.map(_toReview));
      _hasMore = result.hasMore;
      _reviewsLoading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_moreLoading) return;
    setState(() => _moreLoading = true);
    final page = nextReviewPage(_reviews.length);
    final result = await _api.fetchReviews(
      widget.detail.name,
      start: page.start,
      display: page.display,
    );
    if (!mounted) return;
    setState(() {
      _reviews.addAll(result.reviews.map(_toReview));
      _hasMore = result.hasMore;
      _moreLoading = false;
    });
  }

  BlogReview _toReview(review_api.BlogReview review) => BlogReview(
        title: review.title,
        blogName: review.bloggerName,
        date: review.displayDate,
        snippet: review.description,
        url: review.link,
      );

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.48,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildDivider()),
              SliverToBoxAdapter(child: _buildPhotos()),
              SliverToBoxAdapter(child: _buildSummary()),
              SliverToBoxAdapter(child: _buildReviewsHeader()),
              if (_reviewsLoading)
                SliverToBoxAdapter(child: _buildReviewsLoading())
              else if (_reviews.isEmpty)
                SliverToBoxAdapter(child: _buildEmptyReviews())
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => BlogReviewCard(review: _reviews[index]),
                    childCount: _reviews.length,
                  ),
                ),
              if (_hasMore && !_reviewsLoading)
                SliverToBoxAdapter(child: _buildMoreButton()),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.paddingOf(context).bottom + 24,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final tag = tagForCategory(widget.detail.category);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.neutralScale[200],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.detail.name,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutralScale[700],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _handleToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isAdded
                          ? [AppColors.neutralScale[300]!, AppColors.neutralScale[400]!]
                          : [const Color(0xFFCB2FFF), const Color(0xFFD864FF)],
                      stops: _isAdded ? null : const [0.14, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neutralScale[600]!.withAlpha(0x0F),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    _isAdded ? '추가됨 ✓' : '+ 내 경로에 추가하기',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.detail.address,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.neutralScale[400],
            ),
          ),
          const SizedBox(height: 6),
          if (tag != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryScale[0],
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryScale[400],
                ),
              ),
            ),
          const SizedBox(height: 14),
          PlacePhotoHero(photos: _photos),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Divider(color: AppColors.neutralScale[100], thickness: 1),
    );
  }

  /// 사진 목록. 첫 장은 위 큰 자리에 이미 걸려 있어 여기서는 건너뛴다.
  /// 남는 것이 없으면 공용 위젯이 영역째 접는다.
  Widget _buildPhotos() => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
        child: PlacePhotoStrip(
          photos: _photos.length > 1 ? _photos.sublist(1) : const [],
        ),
      );

  /// 요약 자리. 받아오는 동안은 자리만 잡고, 근거를 못 구했으면 접는다.
  Widget _buildSummary() {
    if (_summaryLoading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
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
    return PlaceAiSummaryCard(summary: _bullets.join('\n'));
  }

  Widget _buildReviewsLoading() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildEmptyReviews() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Text(
        '아직 등록된 후기가 없어요.',
        style: TextStyle(
          fontSize: 13,
          color: AppColors.neutralScale[300],
        ),
      ),
    );
  }

  Widget _buildReviewsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/svg/icons/blog_logo.svg',
            width: 22,
            height: 22,
          ),
          const SizedBox(width: 8),
          Text(
            '블로그 리뷰',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.neutralScale[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
      child: Center(
        child: GestureDetector(
          onTap: _moreLoading ? null : _loadMore,
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            decoration: BoxDecoration(
            color: AppColors.reviewMoreButtonBg,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: AppColors.tripOriginChipBorder, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '블로그 리뷰 더보기',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.tripAccentPurple,
                ),
              ),
              const SizedBox(width: 6),
              if (_moreLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  PhosphorIcons.caretDown(),
                  size: 16,
                  color: AppColors.tripAccentPurple,
                ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
