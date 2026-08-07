import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/theme/app_icons.dart';
import '../../../common/utils/d_day.dart';
import '../../../common/widgets/app_confirm_dialog.dart';
import '../../../common/widgets/app_loading_indicator.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/schedule_api_service.dart';
import '../../../core/router/app_router.dart';
import '../../../core/state/trip_repository.dart';
import '../utils/open_schedule.dart';

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

  List<ScheduleSummary> _schedules = const [];
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    TripRepository.instance.requestedTab.addListener(_onTabRequest);
    // 저장 탭은 하단 탭의 한 칸이라 다시 열려도 새로 만들어지지 않는다.
    // 목록이 달라졌다는 신호와 로그인 여부를 직접 듣는다.
    TripRepository.instance.savedRevision.addListener(_load);
    isAuthenticated.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    TripRepository.instance.requestedTab.removeListener(_onTabRequest);
    TripRepository.instance.savedRevision.removeListener(_load);
    isAuthenticated.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (!isAuthenticated.value) {
      if (mounted) {
        setState(() {
          _schedules = const [];
          _loading = false;
          _failed = false;
        });
      }
      return;
    }
    if (mounted) setState(() { _loading = true; _failed = false; });
    try {
      final items = await ScheduleApiService.instance.list();
      if (!mounted) return;
      setState(() { _schedules = items; _loading = false; });
    } on ApiException {
      if (!mounted) return;
      setState(() { _loading = false; _failed = true; });
    }
  }

  Future<void> _openDetail(int scheduleId) =>
      openSchedule(context, scheduleId);

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
                child: AppIcon(SvgIcons.chevronDownPurple, size: 12),
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

  Widget _buildCompletedList() =>
      _buildList(completed: true, emptyText: '완료된 일정이 없어요.');

  // ── 예정된 일정 목록 ───────────────────────────────────────

  Widget _buildPlannedList() => _buildList(
        completed: false,
        emptyText: '저장된 예정 일정이 없어요.\n여행 계획에서 일정을 저장해보세요!',
      );

  /// 예정·완료는 종료일로 가른다. 서버에 완료 표시가 따로 없다.
  Widget _buildList({required bool completed, required String emptyText}) {
    if (!isAuthenticated.value) {
      return _buildEmpty('로그인하면 저장한 일정을 볼 수 있어요.');
    }
    if (_loading) {
      return const Center(child: AppLoadingIndicator());
    }
    if (_failed) {
      return _buildRetry();
    }
    final today = DateTime.now();
    final cards = _sortByRegisteredAt(_schedules
        .where((s) {
          final end = s.dateEnd ?? s.dateStart;
          final past = end != null && daysUntil(end, now: today) < 0;
          return completed ? past : !past;
        })
        .map((s) => _TripCardData(
              scheduleId: s.scheduleId,
              name: s.title.isEmpty ? '이름 없는 일정' : s.title,
              startDate: s.dateStart ?? today,
              endDate: s.dateEnd ?? s.dateStart ?? today,
              registeredAt: s.createdAt ?? s.dateStart ?? today,
            ))
        .toList());
    if (cards.isEmpty) return _buildEmpty(emptyText);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        itemCount: cards.length,
        separatorBuilder: (context, i) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _buildTripCard(cards[i], completed: completed),
      ),
    );
  }

  /// 목록이 서버로 옮겨진 뒤로는 지우는 길이 없으면 시험 삼아 만든 일정이
  /// 계속 쌓인다. 되돌릴 수 없는 동작이라 확인을 한 번 받는다.
  Future<void> _confirmDelete(_TripCardData card) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppConfirmDialog(
        content: Text(
          '‘${card.name}’ 일정을 지울까요?\n되돌릴 수 없어요.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: AppColors.neutralScale[500]),
        ),
        confirmLabel: '삭제',
        onCancel: () => Navigator.of(dialogContext).pop(false),
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (ok != true) return;
    try {
      await ScheduleApiService.instance.delete(card.scheduleId);
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Widget _buildRetry() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('일정을 불러오지 못했어요',
                style: TextStyle(
                    fontSize: 14, color: AppColors.neutralScale[300])),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _load,
              child: Text('다시 시도',
                  style: TextStyle(
                      fontSize: 14,
                      color: AppColors.primaryScale[500],
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  List<_TripCardData> _sortByRegisteredAt(List<_TripCardData> trips) {
    final sorted = [...trips]
      ..sort((a, b) => a.registeredAt.compareTo(b.registeredAt));
    return _sortNewestFirst ? sorted.reversed.toList() : sorted;
  }

  // ── 카드 위젯 ────────────────────────────────────────────

  Widget _buildTripCard(_TripCardData card, {required bool completed}) {
    return GestureDetector(
      onTap: () => _openDetail(card.scheduleId),
      onLongPress: () => _confirmDelete(card),
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
    final days = daysUntil(startDate);
    final label = dDayLabel(startDate);
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
  final int scheduleId;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime registeredAt;

  const _TripCardData({
    required this.scheduleId,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.registeredAt,
  });
}
