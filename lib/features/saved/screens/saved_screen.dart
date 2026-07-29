import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/theme/app_icons.dart';
import '../../../core/state/trip_repository.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  int _tabIndex = 0;
  bool _sortNewestFirst = true; // true: 등록순(최신), false: 오래된순
  bool _sortMenuOpen = false;
  final LayerLink _sortButtonLink = LayerLink();

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
    setState(() {
      _tabIndex = TripRepository.instance.requestedTab.value;
      _sortMenuOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (_sortMenuOpen) setState(() => _sortMenuOpen = false);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
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
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.neutralScale[600],
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '저장한 여행 일정을 확인해보세요.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.tabBarUnselected,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: _buildTabs()),
                        _buildSortButton(),
                      ],
                    ),
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
          ),
          if (_sortMenuOpen)
            Positioned(
              child: CompositedTransformFollower(
                link: _sortButtonLink,
                showWhenUnlinked: false,
                targetAnchor: Alignment.bottomRight,
                followerAnchor: Alignment.topRight,
                offset: const Offset(0, 8),
                child: _buildSortMenu(),
              ),
            ),
        ],
      ),
    );
  }

  // ── 탭 버튼 행 ────────────────────────────────────────────────

  Widget _buildTabs() {
    return Row(
      children: [
        _buildTabPill('예정된 일정', 0),
        const SizedBox(width: 8),
        _buildTabPill('완료된 일정', 1),
      ],
    );
  }

  Widget _buildTabPill(String label, int index) {
    final isSelected = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() {
        _tabIndex = index;
        _sortMenuOpen = false;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.secondaryScale[200]!.withAlpha(153)
              : null,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? AppColors.gradientScale[500]
                : AppColors.savedTabInactive,
          ),
        ),
      ),
    );
  }

  // ── 정렬 드롭다운 ──────────────────────────────────────────

  Widget _buildSortButton() {
    return CompositedTransformTarget(
      link: _sortButtonLink,
      child: GestureDetector(
        onTap: () => setState(() => _sortMenuOpen = !_sortMenuOpen),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.neutralScale[0]!.withAlpha(204),
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                color: AppColors.secondaryScale[900]!.withAlpha(15),
                blurRadius: 10,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _sortNewestFirst ? '등록순' : '오래된순',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.neutralScale[600],
                ),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _sortMenuOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 150),
                child: AppIcon(SvgIcons.chevronDownGray, size: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortMenu() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSortOption('등록순', selected: _sortNewestFirst),
          _buildSortOption('오래된순', selected: !_sortNewestFirst),
        ],
      ),
    );
  }

  Widget _buildSortOption(String label, {required bool selected}) {
    return GestureDetector(
      onTap: () => setState(() {
        _sortNewestFirst = label == '등록순';
        _sortMenuOpen = false;
      }),
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        color: selected
            ? AppColors.secondaryScale[500]
            : AppColors.savedSortUnselected,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white,
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
        final cards = _sortByRegisteredAt(trips
            .map((t) => _TripCardData(
                  name: t.name,
                  startDate: t.tripStartDate,
                  endDate: t.tripEndDate,
                  registeredAt: t.savedAt,
                  savedTrip: t,
                ))
            .toList());
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          itemCount: cards.length,
          separatorBuilder: (context, i) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _buildTripCard(cards[i], completed: true),
        );
      },
    );
  }

  // ── 예정된 일정 목록 ───────────────────────────────────────

  Widget _buildPlannedList() {
    return ValueListenableBuilder<List<SavedTrip>>(
      valueListenable: TripRepository.instance.plannedTrips,
      builder: (context, savedTrips, _) {
        if (savedTrips.isEmpty) {
          return _buildEmpty('저장된 예정 일정이 없어요.\n여행 계획에서 일정을 저장해보세요!');
        }
        final trips = _sortByRegisteredAt(savedTrips
            .map((t) => _TripCardData(
                  name: t.name,
                  startDate: t.tripStartDate,
                  endDate: t.tripEndDate,
                  registeredAt: t.savedAt,
                  savedTrip: t,
                ))
            .toList());
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          itemCount: trips.length,
          separatorBuilder: (context, i) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _buildTripCard(trips[i], completed: false),
        );
      },
    );
  }

  List<_TripCardData> _sortByRegisteredAt(List<_TripCardData> trips) {
    final sorted = [...trips]
      ..sort((a, b) => a.registeredAt.compareTo(b.registeredAt));
    return _sortNewestFirst ? sorted.reversed.toList() : sorted;
  }

  // ── 카드 위젯 ────────────────────────────────────────────

  Widget _buildTripCard(_TripCardData card, {required bool completed}) {
    return GestureDetector(
      onTap: () => context.go('/saved/trip', extra: card.savedTrip),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 21),
        decoration: BoxDecoration(
          color: AppColors.neutralScale[0],
          borderRadius: BorderRadius.circular(20),
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
                      completed
                          ? _buildCompletedBadge(card.endDate)
                          : _buildPlannedBadge(card.startDate),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          card.name,
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
                    '${_fmtDate(card.startDate)} ~ ${_fmtDate(card.endDate)}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.savedBadgeFar,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AppIcon(
              SvgIcons.chevronRightThin,
              size: 16,
              color: AppColors.neutralScale[200],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlannedBadge(DateTime startDate) {
    final days = _dateOnly(startDate).difference(_dateOnly(DateTime.now())).inDays;
    final label = days <= 0 ? 'D-DAY' : 'D-$days';
    final color = days <= 0
        ? AppColors.savedBadgeUrgent
        : days <= 49
            ? AppColors.secondaryScale[500]!
            : AppColors.savedBadgeFar;
    return _badge(label, background: color, textColor: Colors.white);
  }

  Widget _buildCompletedBadge(DateTime endDate) {
    final days = _dateOnly(DateTime.now()).difference(_dateOnly(endDate)).inDays;
    final label = 'D+${days < 0 ? 0 : days}';
    return _badge(
      label,
      background: AppColors.neutralScale[0]!,
      textColor: AppColors.secondaryScale[500]!,
      border: AppColors.secondaryScale[500],
    );
  }

  Widget _badge(
    String label, {
    required Color background,
    required Color textColor,
    Color? border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(100),
        border: border != null ? Border.all(color: border) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
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

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  String _fmtDate(DateTime dt) =>
      '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}.';
}

class _TripCardData {
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime registeredAt;
  final SavedTrip? savedTrip;

  const _TripCardData({
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.registeredAt,
    this.savedTrip,
  });
}
