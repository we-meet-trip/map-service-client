import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'common/theme/app_colors.dart';
import 'core/router/app_router.dart';
import 'core/services/deep_link_service.dart';
import 'data/repositories/chat_repository.dart';
import 'data/repositories/invite_link_repository.dart';
import 'data/repositories/invite_repository.dart';
import 'data/repositories/api_chat_repository.dart';
import 'data/repositories/api_invite_link_repository.dart';
import 'data/repositories/api_invite_repository.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/chat/providers/chat_room_list_provider.dart';
import 'features/invite/providers/invite_provider.dart';
import 'features/place_explore/data/place_explore_repository.dart';
import 'features/place_explore/data/trip_plan_place_explore_repository.dart';
import 'features/place_explore/providers/place_explore_provider.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ChatRepository>(create: (_) => ApiChatRepository()),
        Provider<InviteLinkRepository>(create: (_) => ApiInviteLinkRepository()),
        Provider<InviteRepository>(create: (_) => ApiInviteRepository()),
        Provider<PlaceExploreRepository>(
          create: (_) => TripPlanPlaceExploreRepository(),
        ),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(
          create: (ctx) => ChatRoomListProvider(ctx.read<ChatRepository>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => InviteProvider(ctx.read<InviteRepository>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) =>
              PlaceExploreProvider(ctx.read<PlaceExploreRepository>()),
        ),
      ],
      child: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  AuthProvider? _authProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      DeepLinkService.init(appRouter);
      _authProvider = context.read<AuthProvider>();
      _authProvider!.addListener(_onAuthChanged);
    });
  }

  @override
  void dispose() {
    _authProvider?.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;

    final inviteProvider = context.read<InviteProvider>();
    final token = inviteProvider.pendingToken;
    if (token != null) {
      inviteProvider.pendingToken = null;
      appRouter.go('/invite/$token');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
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
    );
  }
}
