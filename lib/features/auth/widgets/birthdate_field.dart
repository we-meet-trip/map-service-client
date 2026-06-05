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
  static final int _endYear = DateTime.now().year;

  @override
  State<BirthdateField> createState() => _BirthdateFieldState();
}

class _BirthdateFieldState extends State<BirthdateField> {
  bool _isOpen = false;

  Future<void> _pick(BuildContext context) async {
    DateTime tempDate = widget.value ?? DateTime(BirthdateField._endYear - 20);

    setState(() => _isOpen = true);

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
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
                minimumYear: BirthdateField._startYear,
                maximumYear: BirthdateField._endYear,
                onDateTimeChanged: (date) => tempDate = date,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    widget.onChanged(tempDate);
                  },
                  child: const Text('확인'),
                ),
              ),
            ),
          ],
        ),
      ),
    );

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
                          fontSize: 18,
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
