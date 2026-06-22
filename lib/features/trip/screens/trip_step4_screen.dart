import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/theme/app_icons.dart';
import '../widgets/transport_theme.dart';
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
      theme: TransportTheme.bicycle,
      radius: 'RADIUS 10KM', coverage: 70,
      popularText: '내 또래가 가장 많이 선택했어요!',
    ),
    _TransportItem(
      theme: TransportTheme.scooter,
      radius: 'RADIUS 10KM', coverage: 45,
    ),
    _TransportItem(
      theme: TransportTheme.walk,
      radius: 'RADIUS 3KM', coverage: 20,
    ),
    _TransportItem(
      theme: TransportTheme.bus,
      radius: 'RADIUS 10KM', coverage: 20,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return TripStepScaffold(
      onNext: onNext,
      onPrev: onPrev,
      children: [
        TripStepHeader(
          step: 4,
          title: '이동 수단을 선택해 주세요',
          subtitle: '당신의 여정에 가장 적합한 방식을 제안합니다.',
          isNextEnabled: true,
        ),
        const SizedBox(height: 24),
        ..._items.map((item) {
          final isSel = selectedTransport == item.theme.id;
          final faded = selectedTransport != null && !isSel;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: faded ? 0.38 : 1.0,
              child: _TransportCard(
                item: item,
                isSelected: isSel,
                onTap: () => onTransportChanged(isSel ? null : item.theme.id),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ─── 데이터 모델 ──────────────────────────────────────────────

class _TransportItem {
  final TransportTheme theme;
  final String radius;
  final int coverage;
  final String? popularText;

  const _TransportItem({
    required this.theme,
    required this.radius,
    required this.coverage,
    this.popularText,
  });
}

// ─── 카드 위젯 ────────────────────────────────────────────────

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
    final t = item.theme;
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
                    color: t.iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: AppIcon(t.svgPath, size: 18)),
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
                                color: t.iconColor,
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: t.badgeBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(item.radius,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: t.badgeFg,
                          letterSpacing: 0.5)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(t.name,
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
                valueColor: AlwaysStoppedAnimation<Color>(t.barColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
