import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../common/theme/app_colors.dart';
import '../../../core/state/trip_repository.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    TripRepository.instance.requestedTab.addListener(_onTabRequest);
  }

  @override
  void dispose() {
    TripRepository.instance.requestedTab.removeListener(_onTabRequest);
    super.dispose();
  }

  void _onTabRequest() {
    setState(() => _tabIndex = TripRepository.instance.requestedTab.value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 헤더 ──
        Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top + 24,
            20,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '저장된 일정',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.neutralScale[600],
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 20),
              _buildTabRow(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // ── 카드 목록 ──
        Expanded(
          child: _tabIndex == 0
              ? _buildPlannedList()
              : _buildCompletedList(),
        ),
      ],
    );
  }

  // ── 탭 + 소트 버튼 행 ────────────────────────────────────────

  Widget _buildTabRow() {
    return Row(
      children: [
        _buildTabButton('예정된 일정', 0),
        const SizedBox(width: 8),
        _buildTabButton('완료된 일정', 1),
        const Spacer(),
        // 등록순 소트 버튼
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.neutralScale[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '등록순',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.neutralScale[400],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: AppColors.neutralScale[400],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8B3FD6) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(color: AppColors.neutralScale[200]!, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? Colors.white : AppColors.neutralScale[300],
          ),
        ),
      ),
    );
  }

  // ── 완료된 일정 목록 ────────────────────────────────────────

  Widget _buildCompletedList() {
    return ValueListenableBuilder<List<SavedTrip>>(
      valueListenable: TripRepository.instance.completedTrips,
      builder: (context, trips, _) {
        if (trips.isEmpty) {
          return _buildEmpty('완료된 일정이 없어요.');
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          itemCount: trips.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final trip = trips[i];
            return GestureDetector(
              onTap: () => context.push('/navigation', extra: trip),
              child: _buildCard(
                name: trip.name,
                savedAt: trip.savedAt,
                index: i,
                isCompleted: true,
              ),
            );
          },
        );
      },
    );
  }

  // ── 예정된 일정 목록 ───────────────────────────────────────

  Widget _buildPlannedList() {
    return ValueListenableBuilder<List<SavedTrip>>(
      valueListenable: TripRepository.instance.plannedTrips,
      builder: (context, trips, _) {
        if (trips.isEmpty) {
          return _buildEmpty('저장된 예정 일정이 없어요.\n여행 계획에서 일정을 저장해보세요!');
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          itemCount: trips.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final t = trips[trips.length - 1 - i]; // 최신순
            return GestureDetector(
              onTap: () => context.go('/saved/trip', extra: t),
              child: _buildCard(
                name: t.name,
                savedAt: t.savedAt,
                index: i,
                isCompleted: false,
              ),
            );
          },
        );
      },
    );
  }

  // ── 통합 카드 ────────────────────────────────────────────

  Widget _buildCard({
    required String name,
    required DateTime savedAt,
    required int index,
    required bool isCompleted,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F6F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 좌측: 배지 + 여행이름 / 날짜
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildDdayBadge(savedAt, index, isCompleted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.neutralScale[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _formatDate(savedAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.neutralScale[300],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 우측: chevron 아이콘
          Icon(
            Icons.chevron_right_rounded,
            size: 22,
            color: AppColors.neutralScale[300],
          ),
        ],
      ),
    );
  }

  Widget _buildDdayBadge(DateTime savedAt, int index, bool isCompleted) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final savedOnly = DateTime(savedAt.year, savedAt.month, savedAt.day);
    final diff = savedOnly.difference(todayOnly).inDays;

    String label;
    Color bgColor;
    Color textColor = Colors.white;

    if (!isCompleted) {
      // 예정된 일정: D-day 계산
      if (diff == 0) {
        label = 'D-DAY';
        bgColor = const Color(0xFFE0489A);
      } else if (diff > 0 && diff < 50) {
        label = 'D-$diff';
        bgColor = AppColors.primaryScale[500]!;
      } else if (diff >= 50) {
        label = 'D-$diff';
        bgColor = const Color(0xFF9A9A9A);
      } else {
        // diff < 0: 지난 날짜인데 예정 탭에 있는 경우
        label = 'D+${-diff}';
        bgColor = const Color(0xFF9A9A9A);
      }
    } else {
      // 완료된 일정: D+ 배지
      label = diff <= 0 ? 'D+${-diff}' : 'D-$diff';
      if (index % 2 == 1) {
        // 홀수 index
        bgColor = const Color(0xFFEADBFA);
        textColor = AppColors.primaryScale[500]!;
      } else {
        // 짝수 index
        bgColor = const Color(0xFFFBE6F2);
        textColor = const Color(0xFFE0489A);
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildEmpty(String message) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          color: AppColors.neutralScale[300],
          height: 1.6,
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
