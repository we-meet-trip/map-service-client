import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/app_icons.dart';

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
          icon: PhosphorIcon(AppIcons.navHome),
          selectedIcon: PhosphorIcon(AppIcons.navHomeFill),
          label: '홈',
        ),
        NavigationDestination(
          icon: PhosphorIcon(AppIcons.navTrip),
          selectedIcon: PhosphorIcon(AppIcons.navTripFill),
          label: '여행 계획',
        ),
        NavigationDestination(
          icon: PhosphorIcon(AppIcons.navSaved),
          selectedIcon: PhosphorIcon(AppIcons.navSavedFill),
          label: '저장',
        ),
        NavigationDestination(
          icon: PhosphorIcon(AppIcons.navMypage),
          selectedIcon: PhosphorIcon(AppIcons.navMypageFill),
          label: '마이',
        ),
      ],
    );
  }
}