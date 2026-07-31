import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/back_header.dart';

class BikeScooterLocationScreen extends StatelessWidget {
  const BikeScooterLocationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            BackHeader(title: '자전거·킥보드 위치', onBack: () => context.pop()),
            Expanded(
              child: Center(
                child: Text(
                  '준비 중인 기능이에요.',
                  style: TextStyle(color: AppColors.neutralScale[400]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
