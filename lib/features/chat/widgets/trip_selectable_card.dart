import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';
import '../../../core/state/trip_repository.dart';

class TripSelectableCard extends StatelessWidget {
  final SavedTrip trip;
  final bool isSelected;
  final VoidCallback onTap;

  const TripSelectableCard({
    super.key,
    required this.trip,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 21),
        decoration: BoxDecoration(
          color: AppColors.neutralScale[0],
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: AppColors.secondaryScale[500]!, width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: AppColors.secondaryScale[900]!.withAlpha(15),
              blurRadius: 10,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildDDayBadge(trip.tripStartDate),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          trip.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.neutralScale[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Text(
                    '${_fmtDate(trip.tripStartDate)} ~ ${_fmtDate(trip.tripEndDate)}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.savedBadgeFar,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _RadioDot(selected: isSelected),
          ],
        ),
      ),
    );
  }

  Widget _buildDDayBadge(DateTime startDate) {
    final days = _dateOnly(startDate).difference(_dateOnly(DateTime.now())).inDays;
    final label = days <= 0 ? 'D-DAY' : 'D-$days';
    final color = days <= 0
        ? AppColors.savedBadgeUrgent
        : days <= 49
            ? AppColors.secondaryScale[500]!
            : AppColors.savedBadgeFar;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  String _fmtDate(DateTime dt) =>
      '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}.';
}

class _RadioDot extends StatelessWidget {
  final bool selected;
  const _RadioDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.secondaryScale[500] : Colors.transparent,
        border: Border.all(
          color: selected
              ? AppColors.secondaryScale[500]!
              : AppColors.neutralScale[200]!,
          width: 2,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : null,
    );
  }
}
