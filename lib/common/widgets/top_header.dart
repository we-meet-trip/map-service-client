import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class TopHeader extends StatelessWidget implements PreferredSizeWidget {
  const TopHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SvgPicture.asset(
        'assets/svg/top_header.svg',
        fit: BoxFit.fitWidth,
        alignment: Alignment.topCenter,
      ),
    );
  }
}
