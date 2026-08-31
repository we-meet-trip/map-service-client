import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../common/layout/main_layout.dart';
import '../../data/models/chat_room.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/invite_link_repository.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/trip/screens/trip_regenerate_screen.dart';
import '../../features/trip/screens/trip_created_screen.dart';
import '../../features/place_explore/screens/place_explore_step1_screen.dart';
import '../../features/place_explore/screens/place_explore_step2_screen.dart';
import '../../features/place_explore/providers/place_explore_provider.dart';
import '../../features/trip/screens/trip_directions_screen.dart';
import '../../features/trip/screens/place_pick_screen.dart';
import '../../features/trip/screens/search_step1_screen.dart';
import '../../features/saved/screens/saved_screen.dart';
import '../../features/chat/providers/chat_room_detail_provider.dart';
import '../../features/chat/screens/chat_room_detail_screen.dart';
import '../state/trip_repository.dart';
import '../api/trip_api_service.dart';
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
import '../../features/chat/screens/trip_selection_for_chat_screen.dart';
import '../../features/invite/screens/invite_handler_screen.dart';
import '../../features/splash/screens/splash_screen.dart';
import '../../common/widgets/app_loading_screen.dart';
import '../../features/mobility/screens/bike_scooter_location_screen.dart';
import '../../features/vision/screens/vision_screen.dart';
import '../../features/saved/screens/navigation_screen.dart';
import '../../features/trip/screens/subway_route_screen.dart';
import '../api/transit_route_options_service.dart';
import '../../features/trip/screens/transit_route_options_screen.dart';
import '../../features/trip/screens/transit_route_map_screen.dart';
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
      path: '/invite/:token',
      builder: (context, state) => InviteHandlerScreen(
        token: state.pathParameters['token']!,
      ),
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
                GoRoute(
                  path: 'place-explore/step1',
                  builder: (context, state) => PlaceExploreStep1Screen(
                    onNext: () {
                      final provider =
                          context.read<PlaceExploreProvider>();
                      provider.commitSelection();
                      provider.loadAllDetails();
                      context.go('/trip/place-explore/step2');
                    },
                    onPrev: () => context.go('/trip/search'),
                  ),
                ),
                GoRoute(
                  path: 'place-explore/step2',
                  builder: (context, state) => PlaceExploreStep2Screen(
                    onNext: () =>
                        context.go('/trip/place-explore/generating'),
                    onPrev: () => context.go('/trip/place-explore/step1'),
                  ),
                ),
                GoRoute(
                  path: 'place-explore/generating',
                  builder: (context, state) => AppLoadingScreen(
                    onComplete: () =>
                        context.go('/trip/place-explore/result'),
                  ),
                ),
                GoRoute(
                  path: 'place-explore/result',
                  builder: (context, state) => TripCreatedScreen(
                    response: state.extra as TripGenerateResponse?,
                  ),
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
                        GoRoute(
                          path: 'transit',
                          // mode 는 쿼리로 받는다. 지하철·버스 버튼이 같은
                          // 화면을 서로 다른 조회 조건으로 연다.
                          builder: (context, state) => TransitRouteOptionsScreen(
                            args: state.extra as SubwayRouteArgs,
                            mode: switch (state.uri.queryParameters['mode']) {
                              'subway' => TransitSearchMode.subway,
                              'bus' => TransitSearchMode.bus,
                              _ => TransitSearchMode.all,
                            },
                          ),
                          routes: [
                            GoRoute(
                              path: 'map',
                              builder: (context, state) => TransitRouteMapScreen(
                                args: state.extra as TransitRouteMapArgs,
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
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/chat',
              builder: (context, state) => const ChatRoomListScreen(),
              routes: [
                GoRoute(
                  path: 'new',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) =>
                      const TripSelectionForChatScreen(),
                ),
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
