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
import '../../features/place_explore/screens/place_explore_result_screen.dart';
import '../../features/place_explore/screens/place_explore_step1_screen.dart';
import '../../features/place_explore/screens/place_explore_step2_screen.dart';
import '../../features/place_explore/providers/place_explore_provider.dart';
import '../../features/trip/screens/trip_directions_screen.dart';
import '../../features/trip/screens/trip_research_result_screen.dart';
import '../../features/trip/screens/manual_plan_entry_screen.dart';
import '../../features/trip/screens/saved_plan_edit_screen.dart';
import '../../features/trip/screens/search_step1_screen.dart';
import '../../features/saved/screens/saved_screen.dart';
import '../../features/chat/providers/chat_room_detail_provider.dart';
import '../../features/chat/screens/chat_room_detail_screen.dart';
import '../../features/chat/screens/chat_room_missing_screen.dart';
import '../state/trip_repository.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/mypage/screens/mypage_screen.dart';
import '../../features/mypage/screens/profile_edit_screen.dart';
import '../../features/mypage/screens/interests_edit_screen.dart';
import '../../features/notice/screens/permission_notice_screen.dart';
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
import '../../features/mobility/screens/bike_scooter_location_screen.dart';
import '../../features/vision/screens/vision_screen.dart';
import '../../features/saved/screens/navigation_screen.dart';
import '../../features/trip/screens/subway_route_screen.dart';
import '../api/transit_route_options_service.dart';
import '../../features/trip/screens/transit_route_options_screen.dart';
import '../../features/trip/screens/transit_route_map_screen.dart';
import '../../common/widgets/address_search_screen.dart';
import '../../data/local/permission_notice_store.dart';
import '../state/auth_store.dart';

/// 로그인 여부 — 화면들이 오래 전부터 이 값을 보고 그린다.
///
/// 실제 판단은 토큰 보관소가 한다. 여기는 그 값을 그대로 비추는 창이라,
/// 두 곳이 어긋나 로그인한 사용자가 로그인 화면으로 튕기는 일이 없다.
final isAuthenticated = AuthStore.instance.isLoggedIn;

/// 로그인 없이 들어올 수 있는 자리.
///
/// 초대가 여기 들어 있어야 한다. 초대 화면은 로그인이 안 되어 있으면 받은
/// 토큰을 스스로 보관해 두고 로그인으로 보낸 뒤, 끝나면 그 방으로 데려간다.
/// 이 목록에서 빠지면 그 화면이 열리기도 전에 관문이 먼저 로그인으로
/// 돌려보내, 링크에 실려 온 토큰이 사라진다.
const _publicPrefixes = [
  '/splash',
  '/auth',
  '/signup',
  '/invite',
  '/permission-notice',
];

/// 관문의 판단만 떼어 둔다. 화면을 띄우지 않고도 확인할 수 있어야 하기
/// 때문이다 — 특히 초대가 열려 있는지는 링크를 눌러 보기 전에는 드러나지
/// 않는 종류라, 검사로 못 박아 두지 않으면 조용히 되돌아간다.
String? authRedirect({
  required bool authed,
  required bool noticeSeen,
  required String location,
}) {
  // 권한 고지 관문이 로그인 관문보다 먼저다. 초대를 면제하는 이유는 위와
  // 같다 — 여기서 먼저 돌려보내면 링크에 실려 온 초대 토큰이 사라진다.
  const noticeExempt = ['/splash', '/permission-notice', '/invite'];
  if (!noticeSeen && !noticeExempt.any((p) => location.startsWith(p))) {
    return '/permission-notice';
  }
  final isPublic = _publicPrefixes.any((p) => location.startsWith(p));
  if (!authed && !isPublic) return '/auth';
  return null;
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  // 로그인하지 않은 사람을 로그인 자리로 보낸다.
  //
  // 서버가 인증을 켜면 토큰 없는 호출은 전부 401 이 되는데, 화면은 그것을
  // "잠시 후 다시 시도" 로만 보여 준다. 그러면 무엇이 문제인지도, 어디서
  // 로그인하는지도 알 길이 없이 앱 전체가 조용히 멎은 것처럼 보인다.
  refreshListenable: isAuthenticated,
  redirect: (context, state) => authRedirect(
    authed: isAuthenticated.value,
    noticeSeen: PermissionNoticeStore.instance.confirmed,
    location: state.matchedLocation,
  ),
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/permission-notice',
      builder: (context, state) => const PermissionNoticeScreen(),
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
                ),
                // 장소를 전부 새로 받아 오는 자리. 기다림도 이 화면이 맡는다 —
                // 조건을 다시 묻지 않으므로 거칠 단계가 없다.
                GoRoute(
                  path: 'research',
                  builder: (context, state) => const TripResearchResultScreen(),
                ),
                // 장소를 직접 넣고 고치는 자리.
                GoRoute(
                  path: 'manual',
                  builder: (context, state) => const ManualPlanEntryScreen(),
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
                    onNext: () => context.go('/trip/place-explore/result'),
                    onPrev: () => context.go('/trip/place-explore/step1'),
                  ),
                ),
                // 동선을 만드는 동안의 기다림도 결과 화면이 함께 맡는다.
                // 화면을 나누면 만들어 낸 일정을 넘길 자리가 라우트 사이의
                // 임시 값뿐이라, 새로고침 한 번에 사라진다.
                GoRoute(
                  path: 'place-explore/result',
                  builder: (context, state) => PlaceExploreResultScreen(
                    selectedIds:
                        context.read<PlaceExploreProvider>().selectedIds,
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
                    // 저장된 일정을 직접 고치는 자리. 고친 결과는 그 일정을
                    // 갈아 끼우므로 새 일정으로 저장하지 않는다.
                    GoRoute(
                      path: 'edit',
                      builder: (context, state) => SavedPlanEditScreen(
                        trip: state.extra as SavedTrip,
                      ),
                    ),
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
                    // 목록에서 들어오면 방을 들고 오지만, 링크로 곧장 들어오거나
                    // 브라우저에서 새로 고치면 들고 올 것이 없다. 그때 값이 있다고
                    // 단정하면 화면이 뜨기도 전에 죽는다.
                    final room = state.extra as ChatRoom?;
                    final roomId = room?.id ?? int.tryParse(state.pathParameters['id'] ?? '');
                    if (roomId == null) {
                      return const ChatRoomMissingScreen();
                    }
                    return ChangeNotifierProvider(
                      create: (ctx) => ChatRoomDetailProvider(
                        ctx.read<ChatRepository>(),
                        ctx.read<InviteLinkRepository>(),
                        roomId,
                      ),
                      child: ChatRoomDetailScreen(room: room, roomId: roomId),
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
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
