import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // common
  static const background = Color(0xFFF9F8FA);
  static const headerGradientStart = Color(0xFFFDFBFF);
  static const headerGradientEnd   = Color(0xFFF2EDF5);
  static const tabBarBackground = Color(0xFF201F21);
  static const tabBarSelected = Color(0xFF201F21);
  static const tabBarUnselected = Color(0xFF6E6C70);
  static const error = Color(0xFFFF1751);

  static const Map<int, Color> neutralScale = {
    0:   Color(0xFFFDFDFE),
    100: Color(0xFFE2E2E3),
    200: Color(0xFFC6C6C7),
    300: Color(0xFF8F8E90),
    400: Color(0xFF585759),
    500: Color(0xFF3C3B3D),
    600: Color(0xFF201F21),
  };

  static const Map<int, Color> primaryScale = {
    0:   Color(0xFFE9E4FF),
    100: Color(0xFFD5CDFF),
    200: Color(0xFFB6A5FF),
    300: Color(0xFF9272FF),
    400: Color(0xFF723AFF),
    500: Color(0xFF6412FF),
    600: Color(0xFF5E01FF),
    700: Color(0xFF5000DA),
    800: Color(0xFF4202B0),
    900: Color(0xFF280078),
  };

  static const Map<int, Color> secondaryScale = {
    0:   Color(0xFFFAF5FF),
    100: Color(0xFFF3E7FF),
    200: Color(0xFFEAD4FF),
    300: Color(0xFFDAB2FF),
    400: Color(0xFFC98CFF),
    500: Color(0xFFAD51FB),
    600: Color(0xFF992EEF),
    700: Color(0xFF841ED2),
    800: Color(0xFF701EAB),
    900: Color(0xFF5C198A),
  };

  static const Map<int, Color> gradientScale = {
    0:   Color(0xFFC98CFF),
    100: Color(0xFFBA7BFB),
    200: Color(0xFFAB69F6),
    300: Color(0xFF8D46ED),
    400: Color(0xFF6F23E4),
    500: Color(0xFF6012DF),
    600: Color(0xFF5000DA),
  };

  // auth
  static const signupCompleteBackground = Color(0xFFF3F0FA);
  static const kakaoContainer = Color(0xFFFEE500);
  static const kakaoText = Color(0xFF000000);

  static const Map<int, Color> redScale = {
    400: Color(0xFFE53935), // 캘린더 일요일
    500: Color(0xFFFF1751), // 에러/경고
  };

  static const Map<int, Color> blueScale = {
    500: Color(0xFF2160FF), // 캘린더 토요일
  };

  static const Map<int, Color> yellowScale = {
    300: Color(0xFFFFDE5D), // 밝은 노랑 (바/뱃지 배경)
    400: Color(0xFFEFBE00), // 기본 노랑 (아이콘/텍스트)
  };

  static const Map<int, Color> tealScale = {
    300: Color(0xFF90F3EA), // 밝은 청록 (바/뱃지 배경)
    400: Color(0xFF42BDB3), // 기본 청록 (아이콘/텍스트)
  };

  // saved
  static const savedBadgeUrgent = Color(0xFFFF3AB7); // D-DAY 뱃지
  static const savedBadgeFar = Color(0xFFACA9AE); // D-50 이상 뱃지 / 날짜 텍스트
  static const savedTabInactive = Color(0xFF9989B2); // 비선택 탭 텍스트
  static const savedSortUnselected = Color(0xFFD6D4D7); // 정렬 메뉴 비선택 옵션 배경

  // saved trip detail / directions
  static const tripAccentPurple = Color(0xFF5422AC); // 출발지 라벨/칩 텍스트, 시작하기 버튼 그라데이션
  static const tripAccentPurpleEnd = Color(0xFFA752F2); // 시작하기 버튼 그라데이션 끝
  static const tripDirectionsPinkEnd = Color(0xFFFF87D3); // 가는 방법 알아보기 버튼 그라데이션 끝
  static const tripOriginChipBg = Color(0xBFF4EEFE); // 출발지 칩 배경 (rgba(244,238,254,0.75))
  static const tripOriginChipBorder = Color(0xFFCFBEFB); // 출발지 칩 테두리

  // mypage
  static const mypageAvatarAccent = Color(0xFF984CFF); // 프로필 아바타 배경/아이콘 색
  static const mypageDivider = Color(0xFFF2F2F3); // 마이페이지 섹션 구분 띠

  static Color avatarColorOf(String id) =>
      avatarColors[id.hashCode.abs() % avatarColors.length];

  static const List<Color> avatarColors = [
    Color(0xFFDDC5FB), // soft lavender
    Color(0xFFB6A5FF), // light purple
    Color(0xFFC98CFF), // medium lavender
    Color(0xFF7FC2E0), // sky blue
    Color(0xFFFFCE6C), // soft yellow
    Color(0xFFFFC0E3), // soft pink
    Color(0xFFC8F3B7), // soft green
    Color(0xFFFBABAB), // soft red
  ];

  // chat
  static const inputBarBg      = Color(0xFFFFFFFF);
  static const shareIcon       = Color(0xFF8D46ED);
  static const myBubbleBg      = Color(0xFF5000DA);
  static const myBubbleText    = Color(0xFFFFFFFF);
  static const otherBubbleBg   = Color(0xFFFFFFFF);
  static const otherBubbleText = Color(0xFF000000);
  static const senderName      = Color(0xFF8164B4);

}