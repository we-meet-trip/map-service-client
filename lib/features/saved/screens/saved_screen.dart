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

  // 완료된 일정 목 데이터
  final List<_TripCard> _completedTrips = [
    _TripCard(
      name: '속초 당일치기 코스',
      route: '속초 버스 터미널 → 속초해변 → 중앙시장',
      savedAt: DateTime(2026, 4, 20, 10, 30),
      isCompleted: true,
    ),
    _TripCard(
      name: '강릉 바다 여행',
      route: '강릉역 → 경포대 → 주문진 수산시장',
      savedAt: DateTime(2026, 3, 15, 14, 0),
      isCompleted: true,
    ),
    _TripCard(
      name: '춘천 닭갈비 투어',
      route: '춘천역 → 닭갈비 골목 → 남이섬',
      savedAt: DateTime(2026, 2, 8, 9, 0),
      isCompleted: true,
    ),
  ];

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
              _buildTabs(),
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

  // ── 탭 ────────────────────────────────────────────────────

  Widget _buildTabs() {
    return Row(
      children: [
        _buildTabButton('예정된 일정', 0),
        const SizedBox(width: 24),
        _buildTabButton('완료된 일정', 1),
      ],
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 20,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected
                    ? AppColors.neutralScale[600]
                    : AppColors.neutralScale[300],
              ),
            ),
            const SizedBox(height: 4),
            if (isSelected)
              Container(
                height: 2.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.gradientScale[200]!,
                      AppColors.gradientScale[600]!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              )
            else
              const SizedBox(height: 2.5),
          ],
        ),
      ),
    );
  }

  // ── 완료된 일정 목록 ────────────────────────────────────────

  Widget _buildCompletedList() {
    if (_completedTrips.isEmpty) {
      return _buildEmpty('완료된 일정이 없어요.');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: _completedTrips.length,
      separatorBuilder: (context, i) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _buildTripCard(_completedTrips[i]),
    );
  }

  // ── 예정된 일정 목록 (실시간) ───────────────────────────────

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
          separatorBuilder: (context, i) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final t = trips[trips.length - 1 - i]; // 최신순
            return GestureDetector(
              onTap: () => context.go('/saved/trip'),
              child: _buildTripCard(_TripCard(
                name: t.name,
                route: t.route,
                savedAt: t.savedAt,
                isCompleted: false,
              )),
            );
          },
        );
      },
    );
  }

  // ── 카드 위젯 ────────────────────────────────────────────

  Widget _buildTripCard(_TripCard card) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.neutralScale[600]!.withAlpha(0x10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 배지 + 날짜
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBadge(card.isCompleted),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 12,
                    color: AppColors.neutralScale[300],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(card.savedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.neutralScale[300],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 경로 (서브타이틀)
          Text(
            card.route,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.neutralScale[300],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          // 일정 이름 (타이틀)
          Text(
            card.name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.neutralScale[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(bool isCompleted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        gradient: isCompleted
            ? null
            : LinearGradient(
                colors: [
                  AppColors.gradientScale[200]!,
                  AppColors.gradientScale[500]!,
                ],
              ),
        color: isCompleted ? AppColors.neutralScale[200] : null,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isCompleted ? '완료된 일정' : '예정된 일정',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isCompleted ? AppColors.neutralScale[500] : Colors.white,
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

class _TripCard {
  final String name;
  final String route;
  final DateTime savedAt;
  final bool isCompleted;

  const _TripCard({
    required this.name,
    required this.route,
    required this.savedAt,
    required this.isCompleted,
  });
}
