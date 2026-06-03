import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // common
  static const background = Color(0xFFF9F8FA); //배경색
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
  static const kakaoContainer = Color(0xFFFEE500);
  static const kakaoText = Color(0xFF000000);



}