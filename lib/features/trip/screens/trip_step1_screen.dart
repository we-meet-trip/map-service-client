import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/theme/app_icons.dart';
import '../widgets/trip_step_header.dart';
import '../widgets/trip_card.dart';
import '../widgets/trip_step_scaffold.dart';
import '../widgets/trip_slider_theme.dart';

const _kSelColor = Color(0xFFEAD4FF);
const _kBarColor = Color(0x4DEAD4FF);
const _kAccent   = Color(0xFF8D46ED);
const _kSatColor = Color(0xFF2160FF);

class TripStep1Screen extends StatefulWidget {
  final VoidCallback onNext;
  final DateTime? startDate;
  final DateTime? endDate;
  final double startHour;
  final double endHour;
  final void Function(DateTime?, DateTime?) onDateChanged;
  final void Function(double, double) onTimeChanged;

  const TripStep1Screen({
    super.key,
    required this.onNext,
    this.startDate,
    this.endDate,
    this.startHour = 9,
    this.endHour = 20,
    required this.onDateChanged,
    required this.onTimeChanged,
  });

  @override
  State<TripStep1Screen> createState() => _TripStep1ScreenState();
}

class _TripStep1ScreenState extends State<TripStep1Screen> {
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    _displayedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  bool get _canProceed => widget.startDate != null && widget.endDate != null;

  void _onDayTapped(DateTime day) {
    final start = widget.startDate;
    final end   = widget.endDate;
    if (start == null || end != null) {
      widget.onDateChanged(day, null);
    } else {
      widget.onDateChanged(
        day.isBefore(start) ? day : start,
        day.isBefore(start) ? start : day,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return TripStepScaffold(
      onNext: _canProceed ? widget.onNext : null,
      children: [
        TripStepHeader(
          step: 1,
          title: '일정을 계획해볼까요?',
          subtitle: '성공적인 여행 계획을 위해 여행 일정을 설정해주세요.',
          isNextEnabled: _canProceed,
        ),
        const SizedBox(height: 28),
        _CalendarCard(
          displayedMonth: _displayedMonth,
          startDate: widget.startDate,
          endDate: widget.endDate,
          onDayTapped: _onDayTapped,
          onPrevMonth: () => setState(() => _displayedMonth =
              DateTime(_displayedMonth.year, _displayedMonth.month - 1)),
          onNextMonth: () => setState(() => _displayedMonth =
              DateTime(_displayedMonth.year, _displayedMonth.month + 1)),
        ),
        const SizedBox(height: 16),
        _TimeSliderCard(
          startHour: widget.startHour,
          endHour: widget.endHour,
          onChanged: widget.onTimeChanged,
        ),
      ],
    );
  }
}

// ─── Calendar Card ────────────────────────────────────────────────────────────

class _CalendarCard extends StatelessWidget {
  final DateTime displayedMonth;
  final DateTime? startDate;
  final DateTime? endDate;
  final void Function(DateTime) onDayTapped;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;

  const _CalendarCard({
    required this.displayedMonth,
    required this.startDate,
    required this.endDate,
    required this.onDayTapped,
    required this.onPrevMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    return TripCard(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildDayHeaders(),
          const SizedBox(height: 4),
          _buildGrid(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    const months = ['1월','2월','3월','4월','5월','6월',
                    '7월','8월','9월','10월','11월','12월'];
    return Row(
      children: [
        AppIcon(SvgIcons.calendar, size: 19),
        const SizedBox(width: 8),
        Text('날짜 선택',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.neutralScale[600])),
        const Spacer(),
        GestureDetector(
          onTap: onPrevMonth,
          child: AppIcon(SvgIcons.chevronLeft, size: 7, color: AppColors.neutralScale[300]),
        ),
        const SizedBox(width: 6),
        Text('${displayedMonth.year}년 ${months[displayedMonth.month - 1]}',
            style: TextStyle(fontSize: 13, color: AppColors.neutralScale[400])),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onNextMonth,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(3.1415926535897932),
            child: AppIcon(SvgIcons.chevronLeft, size: 7, color: AppColors.neutralScale[300]),
          ),
        ),
      ],
    );
  }

  Widget _buildDayHeaders() {
    const days = ['일','월','화','수','목','금','토'];
    return Row(
      children: days.asMap().entries.map((e) {
        final color = e.key == 0
            ? const Color(0xFFE53935)
            : e.key == 6
                ? _kSatColor
                : AppColors.neutralScale[300]!;
        return Expanded(
          child: Center(
            child: Text(e.value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGrid() {
    final firstDay    = DateTime(displayedMonth.year, displayedMonth.month, 1);
    final daysInMonth = DateTime(displayedMonth.year, displayedMonth.month + 1, 0).day;
    final startOffset = firstDay.weekday % 7; // Sun=0
    final rows        = ((startOffset + daysInMonth) / 7).ceil();

    return Column(
      children: List.generate(rows, (row) {
        return Row(
          children: List.generate(7, (col) {
            final idx = row * 7 + col - startOffset;
            if (idx < 0 || idx >= daysInMonth) {
              return Expanded(child: _grayCell(idx, daysInMonth));
            }
            return Expanded(
              child: _dayCell(
                DateTime(displayedMonth.year, displayedMonth.month, idx + 1),
                col,
              ),
            );
          }),
        );
      }),
    );
  }

  Widget _grayCell(int idx, int daysInMonth) {
    final int num = idx < 0
        ? DateTime(displayedMonth.year, displayedMonth.month, 0).day + idx + 1
        : idx - daysInMonth + 1;
    return SizedBox(
      height: 40,
      child: Center(
        child: Text('$num',
            style: TextStyle(fontSize: 13, color: AppColors.neutralScale[200])),
      ),
    );
  }

  Widget _dayCell(DateTime day, int col) {
    final isStart     = startDate != null && _same(day, startDate!);
    final isEnd       = endDate   != null && _same(day, endDate!);
    final inRange     = _inRange(day);
    final isToday     = _same(day, DateTime.now());
    final isSingleSel = isStart && isEnd;

    final Color textColor;
    if (isStart || isEnd) {
      textColor = AppColors.primaryScale[900]!;
    } else if (inRange) {
      textColor = AppColors.primaryScale[800]!;
    } else if (isToday) {
      textColor = AppColors.secondaryScale[700]!;
    } else if (col == 0) {
      textColor = const Color(0xFFE53935);
    } else if (col == 6) {
      textColor = _kSatColor;
    } else {
      textColor = AppColors.neutralScale[400]!;
    }

    return GestureDetector(
      onTap: () => onDayTapped(day),
      child: SizedBox(
        height: 40,
        child: Stack(
          children: [
            if (inRange && !isSingleSel)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: _rangeBar(isStart, isEnd),
                ),
              ),
            if (isToday && !inRange)
              Center(
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: AppColors.secondaryScale[300]!, width: 1.5),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            if (isStart || isEnd)
              Center(
                child: Container(
                  width: 30, height: 30,
                  decoration: const BoxDecoration(
                      color: _kSelColor, shape: BoxShape.circle),
                ),
              ),
            Center(
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      (isStart || isEnd) ? FontWeight.w700 : FontWeight.w400,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rangeBar(bool isStart, bool isEnd) {
    if (isStart && !isEnd) {
      return Row(children: [
        const Expanded(child: SizedBox()),
        Expanded(child: Container(color: _kBarColor)),
      ]);
    }
    if (isEnd && !isStart) {
      return Row(children: [
        Expanded(child: Container(color: _kBarColor)),
        const Expanded(child: SizedBox()),
      ]);
    }
    return Container(color: _kBarColor);
  }

  bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _inRange(DateTime day) {
    if (startDate == null || endDate == null) return false;
    return !day.isBefore(startDate!) && !day.isAfter(endDate!);
  }
}

// ─── Time Slider Card ─────────────────────────────────────────────────────────

class _TimeSliderCard extends StatelessWidget {
  final double startHour;
  final double endHour;
  final void Function(double, double) onChanged;

  const _TimeSliderCard({
    required this.startHour,
    required this.endHour,
    required this.onChanged,
  });

  String _fmt(double h) => '${h.toInt().toString().padLeft(2, '0')}:00';

  void _showPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TimePickerSheet(
        startHour: startHour.toInt(),
        endHour: endHour.toInt(),
        onConfirm: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TripCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(SvgIcons.clock, size: 20),
              const SizedBox(width: 8),
              Text('활동 시간대',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.neutralScale[600])),
              const Spacer(),
              GestureDetector(
                onTap: () => _showPicker(context),
                child: Row(
                  children: [
                    Text('${_fmt(startHour)} - ${_fmt(endHour)}',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.neutralScale[400])),
                    const SizedBox(width: 2),
                    AppIcon(SvgIcons.chevronDownGray, size: 5, color: AppColors.neutralScale[400]),
                  ],
                ),
              ),
            ],
          ),
          SliderTheme(
            data: tripSliderTheme(context),
            child: RangeSlider(
              values: RangeValues(startHour, endHour),
              min: 0, max: 24, divisions: 24,
              onChanged: (v) => onChanged(v.start, v.end),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ['00:00','06:00','12:00','18:00','24:00']
                  .map((t) => Text(t,
                      style: TextStyle(
                          fontSize: 11, color: AppColors.neutralScale[300])))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Time Picker Bottom Sheet ─────────────────────────────────────────────────

class _TimePickerSheet extends StatefulWidget {
  final int startHour;
  final int endHour;
  final void Function(double, double) onConfirm;

  const _TimePickerSheet({
    required this.startHour,
    required this.endHour,
    required this.onConfirm,
  });

  @override
  State<_TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<_TimePickerSheet> {
  late int _start;
  late int _end;

  @override
  void initState() {
    super.initState();
    _start = widget.startHour;
    _end   = widget.endHour;
  }

  String _fmt(int h) => '${h.toString().padLeft(2, '0')}:00';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: 320,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.neutralScale[100],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _pickerLabel('시작 시간'),
                  _pickerLabel('종료 시간'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _HourPicker(
                      initialHour: _start,
                      onChanged: (h) => setState(() => _start = h),
                    ),
                  ),
                  Container(width: 1, color: AppColors.neutralScale[100]),
                  Expanded(
                    child: _HourPicker(
                      initialHour: _end,
                      onChanged: (h) => setState(() => _end = h),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: GestureDetector(
                onTap: () {
                  final s = _start.toDouble();
                  final e = _end > _start
                      ? _end.toDouble()
                      : (_start + 1.0).clamp(0.0, 24.0);
                  widget.onConfirm(s, e);
                  Navigator.pop(context);
                },
                child: Container(
                  width: double.infinity, height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: LinearGradient(colors: [
                      AppColors.primaryScale[700]!,
                      AppColors.secondaryScale[400]!,
                    ]),
                  ),
                  child: Center(
                    child: Text(
                      '${_fmt(_start)} — ${_fmt(_end)}  확인',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pickerLabel(String text) {
    return Expanded(
      child: Center(
        child: Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.neutralScale[400])),
      ),
    );
  }
}

class _HourPicker extends StatefulWidget {
  final int initialHour;
  final void Function(int) onChanged;

  const _HourPicker({required this.initialHour, required this.onChanged});

  @override
  State<_HourPicker> createState() => _HourPickerState();
}

class _HourPickerState extends State<_HourPicker> {
  late final FixedExtentScrollController _ctrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialHour;
    _ctrl = FixedExtentScrollController(initialItem: _current);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: _ctrl,
      itemExtent: 44,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: (h) {
        setState(() => _current = h);
        widget.onChanged(h);
      },
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: 25,
        builder: (context, index) {
          if (index < 0 || index > 24) return null;
          final selected = index == _current;
          return Center(
            child: Text(
              '${index.toString().padLeft(2, '0')}:00',
              style: TextStyle(
                fontSize: 16,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? _kAccent : AppColors.neutralScale[300],
              ),
            ),
          );
        },
      ),
    );
  }
}
