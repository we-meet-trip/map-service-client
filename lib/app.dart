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
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFF201F21)),
          bodySmall:  TextStyle(color: Color(0xFF201F21)),
          bodyLarge:  TextStyle(color: Color(0xFF201F21)),
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
