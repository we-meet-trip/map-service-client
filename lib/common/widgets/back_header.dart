import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 뒤로가기 버튼 + 가운데 정렬 타이틀로 구성된 화면 상단 헤더.
class BackHeader extends StatelessWidget {
  const BackHeader({super.key, required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: AppColors.neutralScale[500]),
            onPressed: onBack,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.neutralScale[600],
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}
