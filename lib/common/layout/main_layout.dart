import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/state/trip_repository.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/draggable_vision_button.dart';
import '../../features/trip/screens/trip_screen.dart';

class MainLayout extends StatelessWidget {
  const MainLayout({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          navigationShell,
          const DraggableVisionButton(),
        ],
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          if (index == navigationShell.currentIndex && index == 1) {
            tripScreenResetNotifier.value++;
          } else if (index == 1) {
            // 다른 탭에서 넘어온 경우. 만들기 마법사가 저장을 마친 판을
            // 들고 있으면 스스로 처음 화면으로 돌아간다.
            TripRepository.instance.markTripTabEntered();
          }
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}