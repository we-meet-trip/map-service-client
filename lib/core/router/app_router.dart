import 'package:go_router/go_router.dart';
import '../../common/layout/main_layout.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/trip/screens/trip_regenerate_screen.dart';
import '../../features/trip/screens/trip_created_screen.dart';
import '../../features/trip/screens/search_step1_screen.dart';
import '../../features/saved/screens/saved_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/mypage/screens/mypage_screen.dart';
import '../../features/splash/screens/splash_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainLayout(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/trip',
              builder: (context, state) => const TripRegenerateScreen(),
              routes: [
                GoRoute(
                  path: 'search',
                  builder: (context, state) => const SearchStep1Screen(),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/saved',
              builder: (context, state) => const SavedScreen(),
              routes: [
                GoRoute(
                  path: 'trip',
                  builder: (context, state) =>
                      const TripCreatedScreen(showBackButton: true),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/chat',
              builder: (context, state) => const ChatScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/mypage',
              builder: (context, state) => const MypageScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);