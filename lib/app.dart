import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'common/theme/app_colors.dart';
import 'core/router/app_router.dart';
import 'data/repositories/chat_repository.dart';
import 'data/repositories/mock_chat_repository.dart';
import 'features/chat/providers/chat_room_list_provider.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ChatRepository>(create: (_) => MockChatRepository()),
        ChangeNotifierProvider(
          create: (ctx) => ChatRoomListProvider(ctx.read<ChatRepository>()),
        ),
      ],
      child: MaterialApp.router(
        title: 'Map Service',
        locale: const Locale('ko', 'KR'),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('ko', 'KR')],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          fontFamily: 'Pretendard',
          scaffoldBackgroundColor: AppColors.background,
          textTheme: TextTheme(
            bodyMedium: TextStyle(color: AppColors.neutralScale[600]),
            bodySmall: TextStyle(color: AppColors.neutralScale[600]),
            bodyLarge: TextStyle(color: AppColors.neutralScale[600]),
          ),
          navigationBarTheme: const NavigationBarThemeData(
            backgroundColor: AppColors.tabBarBackground,
            indicatorColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
          ),
        ),
        routerConfig: appRouter,
      ),
    );
  }
}
