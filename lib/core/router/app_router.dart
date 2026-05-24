import 'package:go_router/go_router.dart';
import '../../common/layout/main_layout.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/trip/screens/trip_screen.dart';
import '../../features/saved/screens/saved_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/mypage/screens/mypage_screen.dart';
import '../../features/auth/screens/auth_screen.dart';
import '../../features/auth/screens/signup_step1_screen.dart';
import '../../features/auth/screens/signup_step2_screen.dart';
import '../../features/auth/screens/signup_step3_screen.dart';
import '../../features/auth/screens/signup_complete_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/auth',
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: '/signup/step1',
      builder: (context, state) => const SignupStep1Screen(),
    ),
    GoRoute(
      path: '/signup/step2',
      builder: (context, state) => const SignupStep2Screen(),
    ),
    GoRoute(
      path: '/signup/step3',
      builder: (context, state) => const SignupStep3Screen(),
    ),
    GoRoute(
      path: '/signup/complete',
      builder: (context, state) => const SignupCompleteScreen(),
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
              builder: (context, state) => const TripScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/saved',
              builder: (context, state) => const SavedScreen(),
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