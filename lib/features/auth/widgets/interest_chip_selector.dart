import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';

class InterestChipSelector extends StatefulWidget {
  const InterestChipSelector({
    super.key,
    required this.items,
    required this.onChanged,
  });

  final List<String> items;
  final ValueChanged<List<String>> onChanged;

  @override
  State<InterestChipSelector> createState() => _InterestChipSelectorState();
}

class _InterestChipSelectorState extends State<InterestChipSelector> {
  final Set<String> _selected = {};

  void _toggle(String item) {
    setState(() {
      if (_selected.contains(item)) {
        _selected.remove(item);
      } else {
        _selected.add(item);
      }
    });
    widget.onChanged(_selected.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: widget.items
          .map((item) => _InterestChip(
                label: item,
                selected: _selected.contains(item),
                onTap: () => _toggle(item),
              ))
          .toList(),
    );
  }
}

class _InterestChip extends StatelessWidget {
  const _InterestChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAD4FF).withValues(alpha: 0.6) : const Color(0xFFEAD4FF).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected
                ? AppColors.gradientScale[500]!
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: selected ? AppColors.gradientScale[500] : AppColors.neutralScale[300],
          ),
        ),
      ),
    );
  }
}
