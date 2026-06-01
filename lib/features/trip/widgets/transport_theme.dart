import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/theme/app_icons.dart';

class TransportTheme {
  final String id;
  final String name;
  final String svgPath;
  final Color iconColor;
  final Color iconBg;
  final Color barColor;
  final Color badgeBg;
  final Color badgeFg;

  const TransportTheme._({
    required this.id,
    required this.name,
    required this.svgPath,
    required this.iconColor,
    required this.iconBg,
    required this.barColor,
    required this.badgeBg,
    required this.badgeFg,
  });

  // ── 자전거 (보라) ──────────────────────────────────────────────
  static final bicycle = TransportTheme._(
    id: 'bicycle',
    name: '자전거',
    svgPath: SvgIcons.transportBicycle,
    iconColor: AppColors.gradientScale[300]!,
    iconBg:    AppColors.gradientScale[300]!.withAlpha(0x1A),
    barColor:  AppColors.gradientScale[300]!,
    badgeBg:   AppColors.gradientScale[300]!.withAlpha(0x33),
    badgeFg:   AppColors.gradientScale[300]!,
  );

  // ── 전동 킥보드 (핑크) ──────────────────────────────────────────
  static final scooter = TransportTheme._(
    id: 'scooter',
    name: '전동 킥보드',
    svgPath: SvgIcons.transportScooter,
    iconColor: AppColors.secondaryScale[400]!,
    iconBg:    AppColors.secondaryScale[400]!.withAlpha(0x1A),
    barColor:  AppColors.secondaryScale[400]!,
    badgeBg:   AppColors.secondaryScale[400]!.withAlpha(0x33),
    badgeFg:   AppColors.secondaryScale[400]!,
  );

  // ── 도보 (노랑) ────────────────────────────────────────────────
  static final walk = TransportTheme._(
    id: 'walk',
    name: '도보',
    svgPath: SvgIcons.transportWalk,
    iconColor: AppColors.yellowScale[400]!,
    iconBg:    AppColors.yellowScale[300]!.withAlpha(0x33),
    barColor:  AppColors.yellowScale[300]!,
    badgeBg:   AppColors.yellowScale[300]!.withAlpha(0x66),
    badgeFg:   AppColors.yellowScale[400]!,
  );

  // ── 버스 (민트) ────────────────────────────────────────────────
  static final bus = TransportTheme._(
    id: 'bus',
    name: '버스',
    svgPath: SvgIcons.transportBus,
    iconColor: AppColors.tealScale[400]!,
    iconBg:    AppColors.tealScale[300]!.withAlpha(0x33),
    barColor:  AppColors.tealScale[300]!,
    badgeBg:   AppColors.tealScale[300]!.withAlpha(0x66),
    badgeFg:   AppColors.tealScale[400]!,
  );

  static final all = [bicycle, scooter, walk, bus];

  /// 이동수단 id로 조회 (trip_step4에서 사용)
  static TransportTheme byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => scooter);

  /// 이동수단 라벨 문자열로 조회 (trip_created에서 사용)
  static TransportTheme byLabel(String label) {
    if (label.contains('자전거') || label.contains('바이크')) return bicycle;
    if (label.contains('킥보드'))                           return scooter;
    if (label.contains('도보') || label.contains('걷'))      return walk;
    if (label.contains('버스'))                            return bus;
    return scooter;
  }
}
