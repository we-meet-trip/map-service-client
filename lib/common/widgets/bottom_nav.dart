import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/app_colors.dart';
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
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: AppColors.background,
        indicatorColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected ? AppColors.tabBarSelected : AppColors.tabBarUnselected,
            size: 26,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            color: isSelected ? AppColors.tabBarSelected : AppColors.tabBarUnselected,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          );
        }),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      child: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onDestinationSelected,
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        height: 70,
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
            icon: PhosphorIcon(AppIcons.navChat),
            selectedIcon: PhosphorIcon(AppIcons.navChatFill),
            label: '대화방',
          ),
          NavigationDestination(
            icon: PhosphorIcon(AppIcons.navMypage),
            selectedIcon: PhosphorIcon(AppIcons.navMypageFill),
            label: 'MY',
          ),
        ],
      ),
    );
  }
}
