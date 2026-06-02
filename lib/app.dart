import 'package:flutter/material.dart';
import 'common/theme/app_colors.dart';
import 'core/router/app_router.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Map Service',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        fontFamily: 'Pretendard',
        scaffoldBackgroundColor: AppColors.background,
        textTheme: TextTheme(
          bodyMedium: TextStyle(color: AppColors.neutralScale[600]),
          bodySmall:  TextStyle(color: AppColors.neutralScale[600]),
          bodyLarge:  TextStyle(color: AppColors.neutralScale[600]),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: AppColors.tabBarBackground,
          indicatorColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      routerConfig: appRouter,
    );
  }
}
