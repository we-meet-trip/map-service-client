import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/theme/app_icons.dart';
import '../widgets/trip_step_header.dart';
import '../widgets/trip_card.dart';
import '../widgets/trip_step_scaffold.dart';
import '../widgets/trip_slider_theme.dart';

const _kMaxBudget  = 9000000.0;  // 슬라이더 최대(900만)
const _kOverBudget = 10000000.0;
const _kStep       = 10000.0;

double _snap(double v) => (v / _kStep).round() * _kStep;

String _fmt(double v) {
  if (v >= _kOverBudget) return '1,000만 원+';
  if (v <= 0) return '0 원';
  return '${(v / 10000).round()}만 원';
}

class TripStep2Screen extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final double minBudget;
  final double maxBudget;
  final void Function(double, double) onBudgetChanged;

  const TripStep2Screen({
    super.key,
    required this.onNext,
    required this.onPrev,
    required this.minBudget,
    required this.maxBudget,
    required this.onBudgetChanged,
  });

  @override
  State<TripStep2Screen> createState() => _TripStep2ScreenState();
}

class _TripStep2ScreenState extends State<TripStep2Screen> {
  late double _min;
  late double _max;

  bool get _canProceed => _min > 0 || _max > 0;

  @override
  void initState() {
    super.initState();
    _min = widget.minBudget;
    _max = widget.maxBudget;
  }

  void _onSliderChanged(RangeValues v) {
    final snappedMax = _snap(v.end);
    setState(() {
      _min = _snap(v.start);
      _max = snappedMax > _kMaxBudget ? _kOverBudget : snappedMax;
    });
    widget.onBudgetChanged(_min, _max);
  }

  void _onMinChanged(double v) {
    setState(() {
      _min = _snap(v).clamp(0.0, _kOverBudget);
      if (_min > _max) _max = _min;
    });
    widget.onBudgetChanged(_min, _max);
  }

  void _onMaxChanged(double v) {
    final snapped = _snap(v);
    setState(() {
      _max = (snapped > _kMaxBudget ? _kOverBudget : snapped).clamp(_min, _kOverBudget);
    });
    widget.onBudgetChanged(_min, _max);
  }

  @override
  Widget build(BuildContext context) {
    return TripStepScaffold(
      onNext: _canProceed ? widget.onNext : null,
      onPrev: widget.onPrev,
      children: [
        TripStepHeader(
          step: 2,
          title: '예산을 정해볼까요?',
          subtitle: '성공적인 여행 계획을 위해 여행 일정을 설정해주세요.',
          isNextEnabled: _canProceed,
        ),
        const SizedBox(height: 28),
        TripCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                AppIcon(SvgIcons.coin, size: 14),
                const SizedBox(width: 8),
                Text('나의 예산',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.neutralScale[600])),
              ]),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _EditableBudgetChip(
                    value: _min,
                    hasError: false,
                    onChanged: _onMinChanged,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('—',
                        style: TextStyle(
                            fontSize: 18,
                            color: AppColors.neutralScale[300])),
                  ),
                  _EditableBudgetChip(
                    value: _max,
                    hasError: false,
                    onChanged: _onMaxChanged,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SliderTheme(
                data: tripSliderTheme(context),
                child: RangeSlider(
                  values: RangeValues(
                    _min.clamp(0, _kMaxBudget),
                    _max.clamp(0, _kMaxBudget),
                  ),
                  min: 0,
                  max: _kMaxBudget,
                  divisions: (_kMaxBudget / _kStep).round(),
                  onChanged: _onSliderChanged,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0 원',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.neutralScale[300])),
                    Text('1,000만 원+',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.neutralScale[300])),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Editable Budget Chip ─────────────────────────────────────────────────────

class _EditableBudgetChip extends StatefulWidget {
  final double value;
  final bool hasError;
  final void Function(double) onChanged;

  const _EditableBudgetChip({
    required this.value,
    required this.hasError,
    required this.onChanged,
  });

  @override
  State<_EditableBudgetChip> createState() => _EditableBudgetChipState();
}

class _EditableBudgetChipState extends State<_EditableBudgetChip> {
  bool _editing = false;
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl  = TextEditingController(text: widget.value.round().toString());
    _focus = FocusNode();
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing) _commit();
    });
  }

  @override
  void didUpdateWidget(_EditableBudgetChip old) {
    super.didUpdateWidget(old);
    if (!_editing) _ctrl.text = widget.value.round().toString();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startEdit() {
    setState(() {
      _editing = true;
      _ctrl.text = widget.value.round().toString();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
      _ctrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _ctrl.text.length,
      );
    });
  }

  void _commit() {
    if (!_editing) return;
    setState(() => _editing = false);
    final raw = double.tryParse(_ctrl.text) ?? widget.value;
    final v = _snap(raw).clamp(0.0, _kOverBudget);
    _focus.unfocus();
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final textColor   = widget.hasError ? AppColors.redScale[500]! : AppColors.neutralScale[600]!;
    final borderColor = widget.hasError
        ? AppColors.redScale[500]!.withAlpha(0x66)
        : AppColors.neutralScale[100]!;
    final bgColor     = widget.hasError
        ? AppColors.redScale[500]!.withAlpha(0x0F)
        : AppColors.background;

    return GestureDetector(
      onTap: _editing ? null : _startEdit,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 120,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: _editing
            ? SizedBox(
                width: 90,
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    suffixText: ' 원',
                  ),
                  onSubmitted: (_) => _commit(),
                  onTapOutside: (_) => _commit(),
                ),
              )
            : Text(
                _fmt(widget.value),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
      ),
    );
  }
}
