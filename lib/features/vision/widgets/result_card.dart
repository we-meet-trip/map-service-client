import 'package:flutter/material.dart';

import '../../../common/theme/app_colors.dart';
import '../models/vision_models.dart';

class ResultCard extends StatelessWidget {
  final VisionResponse response;

  const ResultCard({super.key, required this.response});

  @override
  Widget build(BuildContext context) {
    final identify = response.identifyResult;
    final searches = response.searchResults;

    if (!response.isSuccess || identify == null) {
      return _buildErrorCard(response.error ?? '인식 실패');
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 드래그 핸들
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.neutralScale[200],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                _CategoryBadge(category: identify.category),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    identify.name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.neutralScale[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              identify.description,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.neutralScale[400],
                height: 1.5,
              ),
            ),
          ),
          if (searches.isNotEmpty) ...[
            const Divider(height: 24, indent: 20, endIndent: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: searches
                    .take(2)
                    .map((s) => _SearchItem(result: s))
                    .toList(),
              ),
            ),
          ] else
            const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.error, fontSize: 14),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String category;

  const _CategoryBadge({required this.category});

  static const _labels = {
    'landmark': '랜드마크',
    'food': '음식',
    'product': '상품',
    'animal': '동물',
    'plant': '식물',
    'other': '기타',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryScale[50],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _labels[category] ?? category,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryScale[500],
        ),
      ),
    );
  }
}

class _SearchItem extends StatelessWidget {
  final SearchResult result;

  const _SearchItem({required this.result});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.neutralScale[600],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            result.summary,
            style: TextStyle(fontSize: 12, color: AppColors.neutralScale[400]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
