import 'package:flutter/material.dart';

class TopHeader extends StatelessWidget implements PreferredSizeWidget {
  const TopHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Map Service'),
      centerTitle: false,
    );
  }
}