import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../common/theme/app_colors.dart';
import '../models/place_detail.dart';

class BlogReviewCard extends StatelessWidget {
  final BlogReview review;

  const BlogReviewCard({super.key, required this.review});

  Future<void> _openUrl() async {
    if (review.url.isEmpty) return;
    // 주소는 바깥 검색 결과에서 온다. 모양이 깨진 값이 섞여 들어와도
    // 후기 목록 전체가 예외로 무너지지 않게 여기서 걸러낸다.
    final uri = Uri.tryParse(review.url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.neutralScale[600]!.withAlpha(0x0C),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  review.blogName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutralScale[600],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Text(
                    '|',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutralScale[200],
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    review.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.neutralScale[500],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              review.snippet,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.neutralScale[400],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  review.date,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.neutralScale[300],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _openUrl,
                  child: Text(
                    '더보기 →',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.shareIcon,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
