import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../common/layout/main_layout.dart';
import '../../data/models/chat_room.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/invite_link_repository.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/trip/screens/trip_regenerate_screen.dart';
import '../../features/trip/screens/trip_created_screen.dart';
import '../../features/trip/screens/trip_directions_screen.dart';
import '../../features/trip/screens/search_step1_screen.dart';
import '../../features/saved/screens/saved_screen.dart';
import '../../features/chat/providers/chat_room_detail_provider.dart';
import '../../features/chat/screens/chat_room_detail_screen.dart';
import '../state/trip_repository.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/mypage/screens/mypage_screen.dart';
import '../../features/mypage/screens/profile_edit_screen.dart';
import '../../features/auth/screens/auth_screen.dart';
import '../../features/auth/screens/signup_step1_screen.dart';
import '../../features/auth/screens/signup_step2_screen.dart';
import '../../features/auth/screens/signup_step3_screen.dart';
import '../../features/auth/screens/signup_complete_screen.dart';
import '../../features/invite/screens/invite_handler_screen.dart';
import '../../features/splash/screens/splash_screen.dart';

final isAuthenticated = ValueNotifier<bool>(false);

const _publicPrefixes = ['/splash', '/auth', '/signup'];

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  // refreshListenable: isAuthenticated,
  // redirect: (context, state) {
  //   final authed = isAuthenticated.value;
  //   final loc = state.matchedLocation;
  //   final isPublic = _publicPrefixes.any((p) => loc.startsWith(p));
  //
  //   if (!authed && !isPublic) return '/auth';
  //   return null;
  // },
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/invite/:token',
      builder: (context, state) => InviteHandlerScreen(
        token: state.pathParameters['token']!,
      ),
    ),
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
                  builder: (context, state) => TripCreatedScreen(
                    showBackButton: true,
                    savedTrip: state.extra as SavedTrip?,
                  ),
                  routes: [
                    GoRoute(
                      path: 'directions',
                      builder: (context, state) => TripDirectionsScreen(
                        savedTrip: state.extra as SavedTrip?,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/chat',
              builder: (context, state) => const ChatRoomListScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) {
                    final room = state.extra! as ChatRoom;
                    return ChangeNotifierProvider(
                      create: (ctx) => ChatRoomDetailProvider(
                        ctx.read<ChatRepository>(),
                        ctx.read<InviteLinkRepository>(),
                        room.id,
                      ),
                      child: ChatRoomDetailScreen(room: room),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/mypage',
              builder: (context, state) => const MypageScreen(),
              routes: [
                GoRoute(
                  path: 'edit',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const ProfileEditScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);