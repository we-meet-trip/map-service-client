import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../common/layout/main_layout.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/trip/screens/trip_regenerate_screen.dart';
import '../../features/trip/screens/trip_created_screen.dart';
import '../../features/trip/screens/trip_directions_screen.dart';
import '../../features/trip/screens/place_pick_screen.dart';
import '../../features/trip/screens/search_step1_screen.dart';
import '../../features/saved/screens/saved_screen.dart';
import '../state/trip_repository.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/mypage/screens/mypage_screen.dart';
import '../../features/mypage/screens/profile_edit_screen.dart';
import '../../features/mypage/screens/interests_edit_screen.dart';
import '../../features/mypage/screens/notification_settings_screen.dart';
import '../../features/auth/screens/auth_screen.dart';
import '../../features/auth/screens/email_login_screen.dart';
import '../../features/auth/screens/signup_step1_screen.dart';
import '../../features/auth/screens/signup_step2_screen.dart';
import '../../features/auth/screens/signup_step3_screen.dart';
import '../../features/auth/screens/signup_step4_screen.dart';
import '../../features/auth/screens/interests_onboarding_screen.dart';
import '../../features/auth/screens/signup_complete_screen.dart';
import '../../features/splash/screens/splash_screen.dart';
import '../../features/mobility/screens/bike_scooter_location_screen.dart';
import '../../features/vision/screens/vision_screen.dart';
import '../../features/saved/screens/navigation_screen.dart';
import '../../features/trip/screens/subway_route_screen.dart';
import '../../common/widgets/address_search_screen.dart';
import '../state/auth_store.dart';

/// 로그인 여부 — 화면들이 오래 전부터 이 값을 보고 그린다.
///
/// 실제 판단은 토큰 보관소가 한다. 여기는 그 값을 그대로 비추는 창이라,
/// 두 곳이 어긋나 로그인한 사용자가 로그인 화면으로 튕기는 일이 없다.
final isAuthenticated = AuthStore.instance.isLoggedIn;

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
      path: '/vision',
      builder: (context, state) => const VisionScreen(),
    ),
    GoRoute(
      path: '/navigation',
      builder: (context, state) {
        final trip = state.extra as SavedTrip? ??
            SavedTrip(
              name: '',
              route: '',
              savedAt: DateTime.now(),
              tripStartDate: DateTime.now(),
              tripEndDate: DateTime.now(),
              stops: const [],
              totalDurationMinutes: 0,
            );
        return NavigationScreen(trip: trip);
      },
    ),
    GoRoute(
      path: '/auth',
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: '/auth/email',
      builder: (context, state) => const EmailLoginScreen(),
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
      path: '/signup/step4',
      builder: (context, state) => const SignupStep4Screen(),
    ),
    GoRoute(
      path: '/signup/interests',
      builder: (context, state) => const InterestsOnboardingScreen(),
    ),
    GoRoute(
      path: '/signup/complete',
      builder: (context, state) => const SignupCompleteScreen(),
    ),
    GoRoute(
      path: '/bike-scooter',
      builder: (context, state) => const BikeScooterLocationScreen(),
    ),
    GoRoute(
      path: '/address-search',
      builder: (context, state) => const AddressSearchScreen(),
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
                  routes: [
                    GoRoute(
                      path: 'places',
                      builder: (context, state) => const PlacePickScreen(),
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
                      routes: [
                        GoRoute(
                          path: 'subway',
                          builder: (context, state) => SubwayRouteScreen(
                            args: state.extra as SubwayRouteArgs,
                          ),
                        ),
                      ],
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
              builder: (context, state) => const ChatScreen(),
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
                GoRoute(
                  path: 'interests',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const InterestsEditScreen(),
                ),
                GoRoute(
                  path: 'notifications',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const NotificationSettingsScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
