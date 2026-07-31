import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/theme/app_icons.dart';

class BirthdateField extends StatefulWidget {
  const BirthdateField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  static const int _startYear = 1950;
  static int get _endYear => DateTime.now().year;

  /// 생년월일 선택용 바텀시트를 띄우고 선택된 날짜를 반환한다.
  /// 다이얼로그가 닫혀도 초기값(또는 오늘)을 그대로 반환한다.
  static Future<DateTime> pickDate(BuildContext context, {DateTime? initial}) async {
    final now = DateTime.now();
    DateTime tempDate = initial != null
        ? DateTime(initial.year, initial.month, initial.day)
        : DateTime(now.year, now.month, now.day);

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: false,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 200,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: tempDate,
                minimumYear: _startYear,
                maximumYear: _endYear,
                onDateTimeChanged: (date) => tempDate = date,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    return tempDate;
  }

  @override
  State<BirthdateField> createState() => _BirthdateFieldState();
}

class _BirthdateFieldState extends State<BirthdateField> {
  bool _isOpen = false;

  Future<void> _pick(BuildContext context) async {
    setState(() => _isOpen = true);
    final picked = await BirthdateField.pickDate(context, initial: widget.value);
    widget.onChanged(picked);
    setState(() => _isOpen = false);
  }

  String _format(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y.$m.$d.';
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.value != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTap: () => _pick(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasValue ? _format(widget.value!) : 'yyyy.mm.dd.',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: hasValue
                              ? AppColors.neutralScale[600]
                              : AppColors.neutralScale[300],
                        ),
                      ),
                    ),
                    Icon(
                      AppIcons.chevronDown,
                      size: 18,
                      color: AppColors.neutralScale[300],
                    ),
                  ],
                ),
              ),
              Stack(
                children: [
                  Container(
                    height: 1,
                    color: AppColors.neutralScale[200],
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    height: 1.5,
                    width: (_isOpen || widget.value != null) ? constraints.maxWidth : 0,
                    color: AppColors.secondaryScale[900],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
