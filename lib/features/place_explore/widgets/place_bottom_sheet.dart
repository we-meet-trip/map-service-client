import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
          const SizedBox(height: 4),
          Text(
            widget.detail.category,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryScale[400],
            ),
          ),
          const SizedBox(height: 14),
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

  Widget _buildMoreButton(int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
      child: Center(
        child: GestureDetector(
          onTap: () {
            setState(() {
              _visibleCount = (_visibleCount + _pageSize).clamp(0, total);
            });
          },
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
