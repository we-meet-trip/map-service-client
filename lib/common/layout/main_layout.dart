import 'package:flutter/material.dart';
import '../widgets/top_header.dart';
import '../widgets/bottom_nav.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/trip/screens/trip_screen.dart';
import '../../features/saved/screens/saved_screen.dart';
import '../../features/mypage/screens/mypage_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    TripScreen(),
    SavedScreen(),
    MypageScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TopHeader(),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: _currentIndex,
        onDestinationSelected: (index) =>
            setState(() => _currentIndex = index),
      ),
    );
  }
}