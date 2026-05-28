import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/theme/app_icons.dart';
import '../widgets/trip_step_header.dart';
import '../widgets/trip_step_scaffold.dart';

class TripStep4Screen extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final String? selectedTransport;
  final void Function(String?) onTransportChanged;

  const TripStep4Screen({
    super.key,
    required this.onNext,
    required this.onPrev,
    required this.selectedTransport,
    required this.onTransportChanged,
  });

  static final _items = [
    _TransportItem(
      id: 'bicycle',   name: '자전거',
      svgPath: SvgIcons.transportBicycle,
      radius: 'RADIUS 10KM', coverage: 70,
      iconColor:  AppColors.gradientScale[300]!,
      iconBg:     AppColors.gradientScale[300]!.withAlpha(0x1A),
      barColor:   AppColors.gradientScale[300]!,
      badgeBg:    AppColors.gradientScale[300]!.withAlpha(0x33),
      badgeFg:    AppColors.gradientScale[300]!,
      popularText: '내 또래가 가장 많이 선택했어요!',
    ),
    _TransportItem(
      id: 'scooter',   name: '전동 킥보드',
      svgPath: SvgIcons.transportScooter,
      radius: 'RADIUS 10KM', coverage: 45,
      iconColor:  AppColors.secondaryScale[400]!,
      iconBg:     AppColors.secondaryScale[400]!.withAlpha(0x1A),
      barColor:   AppColors.secondaryScale[400]!,
      badgeBg:    AppColors.secondaryScale[400]!.withAlpha(0x33),
      badgeFg:    AppColors.secondaryScale[400]!,
    ),
    _TransportItem(
      id: 'walk',      name: '도보',
      svgPath: SvgIcons.transportWalk,
      radius: 'RADIUS 3KM', coverage: 20,
      iconColor:  AppColors.yellowScale[400]!,
      iconBg:     AppColors.yellowScale[300]!.withAlpha(0x33),
      barColor:   AppColors.yellowScale[300]!,
      badgeBg:    AppColors.yellowScale[300]!.withAlpha(0x66),
      badgeFg:    AppColors.yellowScale[400]!,
    ),
    _TransportItem(
      id: 'bus',       name: '버스',
      svgPath: SvgIcons.transportBus,
      radius: 'RADIUS 10KM', coverage: 20,
      iconColor:  AppColors.tealScale[400]!,
      iconBg:     AppColors.tealScale[300]!.withAlpha(0x33),
      barColor:   AppColors.tealScale[300]!,
      badgeBg:    AppColors.tealScale[300]!.withAlpha(0x66),
      badgeFg:    AppColors.tealScale[400]!,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return TripStepScaffold(
      onNext: selectedTransport != null ? onNext : null,
      onPrev: onPrev,
      children: [
        TripStepHeader(
          step: 4,
          title: '이동 수단을 선택해 주세요',
          subtitle: '당신의 여정에 가장 적합한 방식을 제안합니다.',
          isNextEnabled: selectedTransport != null,
        ),
        const SizedBox(height: 24),
        ..._items.map((item) {
          final isSel = selectedTransport == item.id;
          final faded = selectedTransport != null && !isSel;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: faded ? 0.38 : 1.0,
              child: _TransportCard(
                item: item,
                isSelected: isSel,
                onTap: () => onTransportChanged(isSel ? null : item.id),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ─── Data model ───────────────────────────────────────────────────────────────

class _TransportItem {
  final String id;
  final String name;
  final String svgPath;
  final String radius;
  final int coverage;
  final Color iconColor;
  final Color iconBg;
  final Color barColor;
  final Color badgeBg;
  final Color badgeFg;
  final String? popularText;

  _TransportItem({
    required this.id,
    required this.name,
    required this.svgPath,
    required this.radius,
    required this.coverage,
    required this.iconColor,
    required this.iconBg,
    required this.barColor,
    required this.badgeBg,
    required this.badgeFg,
    this.popularText,
  });
}

// ─── Transport Card ───────────────────────────────────────────────────────────

class _TransportCard extends StatelessWidget {
  final _TransportItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _TransportCard({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          border: isSelected
              ? Border.all(color: AppColors.gradientScale[500]!, width: 1.5)
              : Border.all(color: Colors.transparent, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.secondaryScale[900]!.withAlpha(0x29)
                  : AppColors.secondaryScale[900]!.withAlpha(0x0F),
              offset: const Offset(0, 1),
              blurRadius: isSelected ? 12 : 10,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: item.iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: AppIcon(item.svgPath, size: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.popularText != null)
                        Text(item.popularText!,
                            style: TextStyle(
                                fontSize: 11,
                                color: item.iconColor,
                                fontWeight: FontWeight.w600)),
                      Text('COVERAGE ${item.coverage}%',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.neutralScale[300],
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.badgeBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(item.radius,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: item.badgeFg,
                          letterSpacing: 0.5)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(item.name,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? AppColors.neutralScale[600]
                        : AppColors.neutralScale[500])),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: item.coverage / 100,
                minHeight: 6,
                backgroundColor: AppColors.neutralScale[100],
                valueColor: AlwaysStoppedAnimation<Color>(item.barColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
