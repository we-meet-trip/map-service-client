import 'package:flutter/material.dart';

const _kGradStart    = Color(0xFF5422AC);
const _kGradEnd      = Color(0xFFA752F2);
const _kShadowColor  = Color(0x40C98CFF); // #C98CFF 25%
const _kDisabledBg   = Color(0xFFD6D4D7);
const _kDisabledText = Color(0xFFFDFDFE);

class TripNextButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;

  const TripNextButton({
    super.key,
    this.onPressed,
    this.label = '다음 단계로',
  });

  bool get _enabled => onPressed != null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          color: _enabled ? null : _kDisabledBg,
          gradient: _enabled
              ? const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [_kGradStart, _kGradEnd],
                )
              : null,
          boxShadow: _enabled
              ? const [
                  BoxShadow(
                    color: _kShadowColor,
                    offset: Offset(0, 24),
                    blurRadius: 28.8,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _enabled ? Colors.white : _kDisabledText,
            ),
          ),
        ),
      ),
    );
  }
}
