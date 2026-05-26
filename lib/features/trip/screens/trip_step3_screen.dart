import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/theme/app_icons.dart';
import '../widgets/trip_step_header.dart';
import '../widgets/trip_card.dart';
import '../widgets/trip_step_scaffold.dart';

class TripStep3Screen extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final Set<String> selectedThemes;
  final void Function(Set<String>) onThemesChanged;

  const TripStep3Screen({
    super.key,
    required this.onNext,
    required this.onPrev,
    required this.selectedThemes,
    required this.onThemesChanged,
  });

  static const _themes = [
    _ThemeItem(id: 'food',     label: '맛집 탐방', svgPath: SvgIcons.themeFood),
    _ThemeItem(id: 'photo',    label: '사진 명소', svgPath: SvgIcons.themePhoto),
    _ThemeItem(id: 'nature',   label: '자연/풍경', svgPath: SvgIcons.themeNature),
    _ThemeItem(id: 'cafe',     label: '카페 투어', svgPath: SvgIcons.themeCafe),
    _ThemeItem(id: 'history',  label: '역사/문화', svgPath: SvgIcons.themeHistory),
    _ThemeItem(id: 'activity', label: '엑티비티',  svgPath: SvgIcons.themeActivity),
    _ThemeItem(id: 'shopping', label: '쇼핑',     svgPath: SvgIcons.themeShopping),
    _ThemeItem(id: 'night',    label: '야경',     svgPath: SvgIcons.themeNight),
  ];

  void _toggle(String id) {
    final next = Set<String>.from(selectedThemes);
    next.contains(id) ? next.remove(id) : next.add(id);
    onThemesChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return TripStepScaffold(
      onNext: selectedThemes.isNotEmpty ? onNext : null,
      onPrev: onPrev,
      children: [
        TripStepHeader(
          step: 3,
          title: '어떤 여행을 원하나요?',
          subtitle: '당신만의 특별한 여정을 위해 여행 테마를 선택해주세요.',
          isNextEnabled: selectedThemes.isNotEmpty,
        ),
        const SizedBox(height: 28),
        TripCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                AppIcon(SvgIcons.sparkleSmall, size: 18, color: AppColors.primaryScale[600]),
                const SizedBox(width: 8),
                Text('여행 테마',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.neutralScale[600])),
              ]),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.3,
                ),
                itemCount: _themes.length,
                itemBuilder: (_, i) {
                  final t = _themes[i];
                  final sel = selectedThemes.contains(t.id);
                  final faded =
                      selectedThemes.isNotEmpty && !sel;
                  return AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: faded ? 0.38 : 1.0,
                    child: _ThemeCell(
                      item: t,
                      selected: sel,
                      onTap: () => _toggle(t.id),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThemeItem {
  final String id;
  final String label;
  final String svgPath;
  const _ThemeItem({required this.id, required this.label, required this.svgPath});
}

class _ThemeCell extends StatelessWidget {
  final _ThemeItem item;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeCell({required this.item, required this.selected, required this.onTap});

  static const _kCellBgSel    = Color(0xFFEAD4FF);
  static const _kBorderSel    = Color(0xFF6012DF);
  static const _kContentSel   = Color(0xFF280078);
  static const _kShadow       = Color(0x0F5C198A); // 6%

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? _kCellBgSel : AppColors.secondaryScale[0],
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: selected ? _kBorderSel : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: _kShadow,
              offset: Offset(0, 1),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(
              item.svgPath,
              size: 18,
              color: selected ? _kContentSel : AppColors.neutralScale[500],
            ),
            const SizedBox(height: 8),
            Text(item.label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? _kContentSel
                        : AppColors.neutralScale[500])),
          ],
        ),
      ),
    );
  }
}
