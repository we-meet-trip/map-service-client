import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';
import '../models/place_detail.dart';

class BlogReviewCard extends StatelessWidget {
  final BlogReview review;

  const BlogReviewCard({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.neutralScale[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.neutralScale[100]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              review.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.neutralScale[700],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              review.snippet,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.neutralScale[500],
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  review.blogName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryScale[400],
                  ),
                ),
                const Spacer(),
                Text(
                  review.date,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.neutralScale[400],
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
