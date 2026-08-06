import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../common/theme/app_colors.dart';

class PlaceAiSummaryCard extends StatelessWidget {
  final String summary;

  const PlaceAiSummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.secondaryScale[500]!,
              AppColors.primaryScale[500]!,
            ],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(1.5),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.secondaryScale[100]!.withValues(alpha: 0.99),
            borderRadius: BorderRadius.circular(12.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
                    size: 16,
                    color: AppColors.primaryScale[500],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'AI 리뷰 요약',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryScale[500],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                summary,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: AppColors.neutralScale[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
