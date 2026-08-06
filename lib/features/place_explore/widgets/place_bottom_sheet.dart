import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../common/theme/app_colors.dart';
import '../models/place_detail.dart';
import 'blog_review_card.dart';
import 'place_ai_summary_card.dart';

class PlaceBottomSheet extends StatefulWidget {
  final PlaceDetail detail;
  final bool isAdded;
  final VoidCallback onToggle;

  const PlaceBottomSheet({
    super.key,
    required this.detail,
    required this.isAdded,
    required this.onToggle,
  });

  @override
  State<PlaceBottomSheet> createState() => _PlaceBottomSheetState();
}

class _PlaceBottomSheetState extends State<PlaceBottomSheet> {
  static const _initialCount = 2;
  static const _pageSize = 5;

  late bool _isAdded;
  int _visibleCount = _initialCount;

  @override
  void initState() {
    super.initState();
    _isAdded = widget.isAdded;
  }

  void _handleToggle() {
    setState(() => _isAdded = !_isAdded);
    widget.onToggle();
  }

  @override
  Widget build(BuildContext context) {
    final reviews = widget.detail.blogReviews;
    final shown = reviews.take(_visibleCount).toList();
    final hasMore = _visibleCount < reviews.length;

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
              SliverToBoxAdapter(child: _buildInfo()),
              SliverToBoxAdapter(child: _buildToggleButton()),
              SliverToBoxAdapter(child: _buildDivider()),
              SliverToBoxAdapter(child: PlaceAiSummaryCard(summary: widget.detail.aiSummary)),
              SliverToBoxAdapter(child: _buildReviewsHeader()),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => BlogReviewCard(review: shown[index]),
                  childCount: shown.length,
                ),
              ),
              if (hasMore)
                SliverToBoxAdapter(child: _buildMoreButton(reviews.length)),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryScale[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.detail.category,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryScale[500],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildImagePlaceholder(),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.neutralScale[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Icon(
          PhosphorIcons.image(),
          size: 40,
          color: AppColors.neutralScale[300],
        ),
      ),
    );
  }

  Widget _buildInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
      child: Column(
        children: [
          _buildInfoRow(PhosphorIcons.mapPin(), widget.detail.address),
          const SizedBox(height: 8),
          _buildInfoRow(PhosphorIcons.clock(), widget.detail.openingHours),
          const SizedBox(height: 8),
          _buildInfoRow(
            PhosphorIcons.star(PhosphorIconsStyle.fill),
            '${widget.detail.rating}',
            iconColor: const Color(0xFFFFC107),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String text, {
    Color? iconColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor ?? AppColors.neutralScale[400]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.neutralScale[500],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: GestureDetector(
        onTap: _handleToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 52,
          decoration: BoxDecoration(
            color: _isAdded ? AppColors.primaryScale[500] : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primaryScale[500]!,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isAdded
                    ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
                    : PhosphorIcons.plusCircle(),
                size: 20,
                color: _isAdded ? Colors.white : AppColors.primaryScale[500],
              ),
              const SizedBox(width: 8),
              Text(
                _isAdded ? '내 경로에 추가됨' : '+ 내 경로에 추가하기',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _isAdded ? Colors.white : AppColors.primaryScale[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Divider(color: AppColors.neutralScale[100], thickness: 1),
    );
  }

  Widget _buildReviewsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Row(
        children: [
          Icon(PhosphorIcons.newspaper(), size: 18, color: AppColors.neutralScale[500]),
          const SizedBox(width: 8),
          Text(
            '블로그 리뷰',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.neutralScale[600],
            ),
          ),
          const Spacer(),
          Text(
            '${widget.detail.blogReviews.length}개',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.neutralScale[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreButton(int total) {
    final remaining = total - _visibleCount;
    final loadCount = remaining.clamp(0, _pageSize);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _visibleCount = (_visibleCount + _pageSize).clamp(0, total);
          });
        },
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.neutralScale[200]!),
          ),
          child: Center(
            child: Text(
              '리뷰 $loadCount개 더 보기',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.neutralScale[500],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
