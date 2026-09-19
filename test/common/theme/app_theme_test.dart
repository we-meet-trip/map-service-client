import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/app.dart';
import 'package:map_service_client/common/theme/app_colors.dart';

/// 스타일을 따로 주지 않은 Material 기본 위젯이 브랜드 색으로 그려지는지 본다.
///
/// 이 검사가 없으면 테마 선언이 빠져도 아무도 모른다 — 앱은 그대로 뜨고,
/// 다이얼로그나 체크박스만 조용히 다른 보라가 된다.
void main() {
  final theme = appTheme;

  test('기본 색이 Flutter 기본 팔레트가 아니라 브랜드 색이다', () {
    expect(theme.colorScheme.primary, AppColors.primaryScale[500]);
    expect(theme.colorScheme.error, AppColors.error);
    // 시드를 브랜드로 바꾸기 전 값. 이 값이 다시 나오면 선언이 사라진 것이다.
    expect(theme.colorScheme.primary, isNot(const Color(0xFF6750A4)));
  });

  test('선언이 없으면 기본 팔레트로 떨어지는 표면들이 전부 지정돼 있다', () {
    expect(theme.dialogTheme.backgroundColor, AppColors.neutralScale[0]);
    expect(theme.bottomSheetTheme.backgroundColor, AppColors.neutralScale[0]);
    expect(theme.popupMenuTheme.color, AppColors.neutralScale[0]);
    expect(theme.snackBarTheme.backgroundColor, AppColors.neutralScale[600]);
    expect(theme.progressIndicatorTheme.color, AppColors.primaryScale[500]);
    expect(theme.textSelectionTheme.cursorColor, AppColors.primaryScale[500]);
  });

  test('표면 틴트를 꺼 흰 카드에 보라가 덧칠되지 않는다', () {
    expect(theme.appBarTheme.surfaceTintColor, Colors.transparent);
    expect(theme.dialogTheme.surfaceTintColor, Colors.transparent);
    expect(theme.bottomSheetTheme.surfaceTintColor, Colors.transparent);
  });

  test('선택된 체크박스가 브랜드 색으로 칠해진다', () {
    final fill = theme.checkboxTheme.fillColor!;
    expect(fill.resolve({WidgetState.selected}), AppColors.primaryScale[500]);
  });

  test('입력칸 테두리는 일부러 지정하지 않는다', () {
    // 선언하면 밑줄형과 상자형이 한 모양으로 눌려 로그인·회원가입 레이아웃이
    // 함께 바뀐다. 강조선 색은 colorScheme.primary 가 이미 맡는다.
    expect(theme.inputDecorationTheme.border, isNull);
    expect(theme.inputDecorationTheme.focusedBorder, isNull);
  });

  test('같은 사람에게는 늘 같은 아바타 색이 나온다', () {
    // String.hashCode 는 실행마다 시드가 달라 같은 계정도 색이 바뀌었다.
    const id = 'store.review.map@gmail.com';
    final first = AppColors.avatarColorOf(id);
    for (var i = 0; i < 50; i++) {
      expect(AppColors.avatarColorOf(id), first);
    }
    expect(AppColors.avatarColorOf('a'), isNot(AppColors.avatarColorOf('b')));
  });
}
