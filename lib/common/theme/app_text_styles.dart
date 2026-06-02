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

  // ─── Gray variants ───────────────────────────────────────────────────────────
  static const body5Gray = TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: gray);
  static const body6Gray = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: gray);
  static const body7Gray = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: gray);
  static const body9Gray = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: gray);
}
