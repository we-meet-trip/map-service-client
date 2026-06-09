import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// ─── Phosphor (내비게이션 등 시스템 아이콘) ────────────────────────────────────
class AppIcons {
  AppIcons._();

  // Bottom Navigation
  static final navHome       = PhosphorIcons.house();
  static final navHomeFill   = PhosphorIcons.house(PhosphorIconsStyle.fill);
  static final navTrip       = PhosphorIcons.mapTrifold();
  static final navTripFill   = PhosphorIcons.mapTrifold(PhosphorIconsStyle.fill);
  static final navSaved      = PhosphorIcons.bookmarkSimple();
  static final navSavedFill  = PhosphorIcons.bookmarkSimple(PhosphorIconsStyle.fill);
  static final navChat       = PhosphorIcons.chatCircleDots();
  static final navChatFill   = PhosphorIcons.chatCircleDots(PhosphorIconsStyle.fill);
  static final navMypage     = PhosphorIcons.user();
  static final navMypageFill = PhosphorIcons.user(PhosphorIconsStyle.fill);

  // Extra
  static final cancel = PhosphorIcons.xCircle(PhosphorIconsStyle.fill);
  static final chevronDown = PhosphorIcons.caretDown();
}

// ─── SVG 커스텀 아이콘 경로 상수 ──────────────────────────────────────────────
//
// 사용법 (경로 직접):
//   SvgPicture.asset(SvgIcons.calendar)
//
// 사용법 (AppIcon 위젯):
//   AppIcon(SvgIcons.calendar)
//   AppIcon(SvgIcons.star, size: 20, color: Color(0xFF5422AC))
class SvgIcons {
  SvgIcons._();

  static const _base = 'assets/svg/icons';

  // ─── UI / Actions ──────────────────────────────────────────────────────────
  static const arrowRight        = '$_base/arrow_right.svg';
  static const chevronLeft       = '$_base/chevron_left.svg';
  static const chevronDownGray   = '$_base/chevron_down_gray.svg';
  static const chevronDownPurple = '$_base/chevron_down_purple.svg';
  static const chevronDownLarge  = '$_base/chevron_down_large.svg';
  static const edit              = '$_base/edit.svg';
  static const checkFilled       = '$_base/check_filled.svg';
  static const checkOutline      = '$_base/check_outline.svg';
  static const star              = '$_base/star.svg';
  static const refresh           = '$_base/refresh.svg';

  // ─── App / Decoration ──────────────────────────────────────────────────────
  static const logo              = '$_base/logo.svg';
  static const sparkle           = '$_base/sparkle.svg';
  static const sparkleSmall      = '$_base/sparkle_small.svg';
  static const person            = '$_base/person.svg';
  static const decoCircleGradient= '$_base/deco_circle_gradient.svg';
  static const decoCircle1       = '$_base/deco_circle1.svg';
  static const decoCircle2       = '$_base/deco_circle2.svg';
  static const decoNodes         = '$_base/deco_nodes.svg';
  static const decoChecklist     = '$_base/deco_checklist.svg';

  // ─── Map / Location ────────────────────────────────────────────────────────
  static const mapPin            = '$_base/map_pin.svg';
  static const mapPinFilled      = '$_base/map_pin_filled.svg';

  // ─── Transport ─────────────────────────────────────────────────────────────
  static const transportBicycle  = '$_base/transport_bicycle.svg';
  static const transportScooter  = '$_base/transport_scooter.svg';
  static const transportBus      = '$_base/transport_bus.svg';
  static const transportCar      = '$_base/transport_car.svg';
  static const transportWalk     = '$_base/transport_walk.svg';

  // ─── Trip Info ─────────────────────────────────────────────────────────────
  static const calendar          = '$_base/calendar.svg';
  static const clock             = '$_base/clock.svg';
  static const checklist         = '$_base/checklist.svg';
  static const coin              = '$_base/coin.svg';

  // ─── Feature ───────────────────────────────────────────────────────────────
  static const featureCircle     = '$_base/feature_circle.svg';
  static const featureBroadcast  = '$_base/feature_broadcast.svg';
  static const featureRadio      = '$_base/feature_radio.svg';

  // ─── Trip Themes (라이트 / 다크 페어) ──────────────────────────────────────
  static const themeFood         = '$_base/theme_food.svg';
  static const themeFoodDark     = '$_base/theme_food_dark.svg';
  static const themeCafe         = '$_base/theme_cafe.svg';
  static const themeCafeDark     = '$_base/theme_cafe_dark.svg';
  static const themeShopping     = '$_base/theme_shopping.svg';
  static const themeShoppingDark = '$_base/theme_shopping_dark.svg';
  static const themeActivity     = '$_base/theme_activity.svg';
  static const themeActivityDark = '$_base/theme_activity_dark.svg';
  static const themeNature       = '$_base/theme_nature.svg';
  static const themeNatureDark   = '$_base/theme_nature_dark.svg';
  static const themePhoto        = '$_base/theme_photo.svg';
  static const themePhotoDark    = '$_base/theme_photo_dark.svg';
  static const themeHistory      = '$_base/theme_history.svg';
  static const themeHistoryDark  = '$_base/theme_history_dark.svg';
  static const themeNight        = '$_base/theme_night.svg';
  static const themeNightDark    = '$_base/theme_night_dark.svg';
}

// ─── AppIcon 위젯 ─────────────────────────────────────────────────────────────
/// SVG 아이콘을 렌더링하는 경량 위젯.
///
///   AppIcon(SvgIcons.calendar)
///   AppIcon(SvgIcons.star, size: 20, color: Color(0xFF5422AC))
class AppIcon extends StatelessWidget {
  final String asset;
  final double size;
  final Color? color;

  const AppIcon(this.asset, {super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
    );
  }
}