import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'common/theme/app_colors.dart';
import 'core/router/app_router.dart';
import 'core/services/deep_link_service.dart';
import 'data/repositories/api_chat_repository.dart';
import 'data/repositories/api_invite_link_repository.dart';
import 'data/repositories/api_invite_repository.dart';
import 'data/repositories/chat_repository.dart';
import 'data/repositories/invite_link_repository.dart';
import 'data/repositories/invite_repository.dart';
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
  // 대기 중인 초대 토큰으로 되돌아가는 일은 로그인이 끝나는 화면들이 맡는다
  // (postLoginRoute). 여기서 로그인 상태 변화를 듣고 이동시키던 때는, 그 이동이
  // 로그인 화면이 뒤이어 하는 이동에 곧바로 덮여 초대가 조용히 끊겼다.

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      DeepLinkService.init(appRouter);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Map Service',
      locale: const Locale('ko', 'KR'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('ko', 'KR')],
      theme: appTheme,
      routerConfig: appRouter,
    );
  }
}

/// 스타일을 따로 주지 않은 Material 기본 위젯이 무엇을 입을지 정하는 곳.
///
/// 여기가 비어 있으면 다이얼로그·스냅바·체크박스·스피너·입력 커서가 전부
/// Flutter 기본 팔레트로 그려진다. 앱의 나머지는 AppColors 를 쓰므로 같은
/// 화면 안에서 두 가지 보라가 섞인다. 그 경계를 없애려고 시드를 브랜드 색으로
/// 바꾸고, 선언이 없던 표면 색들을 앱이 실제로 쓰는 값으로 묶는다.
///
/// 모양(모서리 반경·테두리 형태·배치)은 건드리지 않는다. 색만 맞춘다.
/// 모양까지 한꺼번에 바꾸면 바텀시트 12곳과 입력칸 여러 종류가 동시에 눌려
/// 어느 화면이 왜 달라졌는지 추적할 수 없다.
final ThemeData appTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primaryScale[500]!,
    // 시드에서 파생된 톤이 아니라 브랜드 색 그대로를 쓴다.
    primary: AppColors.primaryScale[500],
    onPrimary: AppColors.neutralScale[0],
    // 기본 오류색(#B3261E)은 앱이 쓰는 경고색과 다르다.
    error: AppColors.error,
    onError: AppColors.neutralScale[0],
  ),
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

  // 표면 틴트는 Material 3 이 surface 위에 primary 를 옅게 덧칠하는 기능이다.
  // 앱의 카드는 흰색이어야 하므로 전부 끈다.
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.background,
    foregroundColor: AppColors.neutralScale[600],
    surfaceTintColor: Colors.transparent,
    elevation: 0,
  ),
  // 색을 주지 않은 Card 는 시드에서 파생된 표면색으로 칠해진다. 외부 AI
  // 동의 설정 화면의 카드가 혼자 연보라로 보인 것이 그 때문이다.
  cardTheme: CardThemeData(
    color: AppColors.neutralScale[0],
    surfaceTintColor: Colors.transparent,
    elevation: 0,
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: AppColors.neutralScale[0],
    surfaceTintColor: Colors.transparent,
  ),
  bottomSheetTheme: BottomSheetThemeData(
    backgroundColor: AppColors.neutralScale[0],
    surfaceTintColor: Colors.transparent,
  ),
  popupMenuTheme: PopupMenuThemeData(
    color: AppColors.neutralScale[0],
    surfaceTintColor: Colors.transparent,
  ),

  // 기본 스낵바는 시드에서 파생된 보라 섞인 검정이다. 앱이 이미 쓰는
  // 탭바 검정으로 맞춘다. 배치(fixed)는 그대로 둬서 레이아웃을 흔들지 않는다.
  snackBarTheme: SnackBarThemeData(
    backgroundColor: AppColors.neutralScale[600],
    contentTextStyle: TextStyle(color: AppColors.neutralScale[0], fontSize: 14),
    actionTextColor: AppColors.primaryScale[200],
  ),

  // 기본 FilledButton 의 비활성 상태는 표면색 위에 흐린 글자라 대비가 낮다.
  // 관문의 '동의하고 계속' 이 회색 위 흰 글자로 거의 읽히지 않았다.
  filledButtonTheme: FilledButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? AppColors.neutralScale[100]
            : AppColors.primaryScale[500],
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? AppColors.neutralScale[400]
            : AppColors.neutralScale[0],
      ),
    ),
  ),
  progressIndicatorTheme: ProgressIndicatorThemeData(
    color: AppColors.primaryScale[500],
    linearTrackColor: AppColors.primaryScale[0],
    circularTrackColor: Colors.transparent,
  ),
  // 입력 커서와 선택 핸들은 지정이 없으면 플랫폼 기본색으로 나온다.
  textSelectionTheme: TextSelectionThemeData(
    cursorColor: AppColors.primaryScale[500],
    selectionColor: AppColors.primaryScale[100],
    selectionHandleColor: AppColors.primaryScale[500],
  ),
  checkboxTheme: CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? AppColors.primaryScale[500]
          : Colors.transparent,
    ),
    checkColor: WidgetStateProperty.all(AppColors.neutralScale[0]),
    side: BorderSide(color: AppColors.neutralScale[300]!, width: 2),
  ),
  radioTheme: RadioThemeData(
    fillColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? AppColors.primaryScale[500]
          : AppColors.neutralScale[300],
    ),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? AppColors.neutralScale[0]
          : AppColors.neutralScale[0],
    ),
    trackColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? AppColors.primaryScale[500]
          : AppColors.neutralScale[200],
    ),
  ),
);

// 입력칸 테두리(InputDecorationTheme)는 일부러 선언하지 않는다.
// Material 3 은 입력칸 강조선에 colorScheme.primary 를 쓰므로 시드를 바꾼 것만으로
// 브랜드 색이 된다. 여기서 테두리 객체를 선언하면 밑줄형과 상자형이 한 모양으로
// 눌려 로그인·회원가입 흐름의 레이아웃이 함께 바뀐다. 그것은 별도 작업이다.
