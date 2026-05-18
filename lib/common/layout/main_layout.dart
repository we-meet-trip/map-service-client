import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/top_header.dart';
import '../widgets/bottom_nav.dart';

class MainLayout extends StatelessWidget {
  const MainLayout({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TopHeader(),
      body: navigationShell,
      bottomNavigationBar: BottomNav(
        currentIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}