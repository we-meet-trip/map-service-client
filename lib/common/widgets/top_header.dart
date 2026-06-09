import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';

class TopHeader extends StatelessWidget implements PreferredSizeWidget {
  const TopHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppColors.headerGradientStart,
            AppColors.headerGradientEnd,
          ],
          stops: const [0.67, 1.0],
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SvgPicture.asset(
            'assets/svg/union.svg',
            height: 28,
          ),
        ),
      ),
    );
  }
}
