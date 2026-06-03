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

  static final int _startYear = 1950;
  static final int _endYear = DateTime.now().year;

  @override
  State<BirthdateField> createState() => _BirthdateFieldState();
}

class _BirthdateFieldState extends State<BirthdateField> {
  bool _isOpen = false;

  Future<void> _pick(BuildContext context) async {
    setState(() => _isOpen = true);
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.value ?? DateTime(BirthdateField._endYear - 20),
      firstDate: DateTime(BirthdateField._startYear),
      lastDate: DateTime(BirthdateField._endYear, 12, 31),
      locale: const Locale('ko'),
    );
    setState(() => _isOpen = false);
    if (picked != null) widget.onChanged(picked);
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
