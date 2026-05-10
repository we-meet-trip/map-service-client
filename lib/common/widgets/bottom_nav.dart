import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: [
        NavigationDestination(
          icon: PhosphorIcon(PhosphorIcons.house()),
          selectedIcon: PhosphorIcon(PhosphorIcons.house(PhosphorIconsStyle.fill)),
          label: '홈',
        ),
        NavigationDestination(
          icon: PhosphorIcon(PhosphorIcons.mapTrifold()),
          selectedIcon: PhosphorIcon(PhosphorIcons.mapTrifold(PhosphorIconsStyle.fill)),
          label: '여행 계획',
        ),
        NavigationDestination(
          icon: PhosphorIcon(PhosphorIcons.bookmarkSimple()),
          selectedIcon: PhosphorIcon(PhosphorIcons.bookmarkSimple(PhosphorIconsStyle.fill)),
          label: '저장',
        ),
        NavigationDestination(
          icon: PhosphorIcon(PhosphorIcons.user()),
          selectedIcon: PhosphorIcon(PhosphorIcons.user(PhosphorIconsStyle.fill)),
          label: '마이',
        ),
      ],
    );
  }
}