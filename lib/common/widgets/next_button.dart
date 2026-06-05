import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

final _kGradStart    = AppColors.secondaryScale[900]!;
final _kGradEnd      = AppColors.secondaryScale[500]!;
final _kShadowColor  = AppColors.gradientScale[0]!.withAlpha(0x40);
final _kDisabledBg   = AppColors.neutralScale[100]!;
final _kDisabledText = AppColors.neutralScale[0]!;

class NextButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final String? info;

  const NextButton({
    super.key,
    this.onPressed,
    this.label = '다음 단계로',
    this.info,
  });

  bool get _enabled => onPressed != null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: info != null ? 68 : 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          color: _enabled ? null : _kDisabledBg,
          gradient: _enabled
              ? LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [_kGradStart, _kGradEnd],
                )
              : null,
          boxShadow: _enabled
              ? [
                  BoxShadow(
                    color: _kShadowColor,
                    offset: const Offset(0, 24),
                    blurRadius: 28.8,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: info != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      info!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: (_enabled ? Colors.white : _kDisabledText)
                            .withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: _enabled ? Colors.white : _kDisabledText,
                      ),
                    ),
                  ],
                )
              : Text(
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
