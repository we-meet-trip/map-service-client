import 'package:flutter/material.dart';

class AppTextStyles {
  AppTextStyles._();

  static const Color black = Color(0xFF201F21);
  static const Color gray  = Color(0xFF6E6B71);

  // ─── Title ───────────────────────────────────────────────────────────────────
  static const title1 = TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: black);
  static const title2 = TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: black);

  // ─── Heading ─────────────────────────────────────────────────────────────────
  static const heading1 = TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: black);
  static const heading2 = TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: black);

  // ─── Body ────────────────────────────────────────────────────────────────────
  static const body1 = TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: black);
  static const body2 = TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: black);
  static const body3 = TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: black);
  static const body4 = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: black);
  static const body5 = TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: black);
  static const body6 = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: black);
  static const body7 = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: black);
  static const body8 = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: black);
  static const body9 = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: black);

  // ─── Detail ──────────────────────────────────────────────────────────────────
  static const detail = TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: black);

  // ── 정본이 아직 덮지 못하는 값 ────────────────────────────────────────────
  //
  // lib/common/widgets 의 인라인 TextStyle 25건 중 위 정본과 크기·굵기가
  // 정확히 맞는 것은 6건뿐이다. 나머지가 쓰는 값은 아래와 같고, 이것이
  // 화면들이 정본을 지나쳐 인라인으로 쓰는 이유다.
  //
  //   정본에 없는 크기 : 11 · 15 · 17 · 22
  //   정본에 없는 굵기 : w700
  //   크기는 있으나 굵기 조합이 없는 것 : 14/w500 · 18/w400
  //
  // 이 값들을 정본에 넣을지, 아니면 화면을 가까운 정본 값으로 옮길지는
  // 디자인 시스템 결정이다. 화면을 옮기면 글자 크기가 1~2px 움직여 좁은
  // 카드에서 줄바꿈과 말줄임이 생기므로 임의로 정하지 않는다.

  // ─── Gray variants ───────────────────────────────────────────────────────────
  static const body5Gray = TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: gray);
  static const body6Gray = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: gray);
  static const body7Gray = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: gray);
  static const body9Gray = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: gray);
}
