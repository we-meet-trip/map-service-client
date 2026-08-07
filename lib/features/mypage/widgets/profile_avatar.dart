import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    this.imagePath,
    this.size = 56,
    this.color = AppColors.mypageAvatarAccent,
    this.showBorder = false,
  });

  final String? imagePath;
  final double size;
  final Color color;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.37),
        color: color,
        border: showBorder
            ? Border.all(color: AppColors.neutralScale[0]!, width: 2.4)
            : null,
        boxShadow: showBorder
            ? [
                BoxShadow(
                  color: AppColors.secondaryScale[900]!.withValues(alpha: 0.06),
                  blurRadius: 3.99,
                  offset: const Offset(0, 0.4),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: imagePath == null
          ? Icon(Icons.person_rounded, color: AppColors.mypageAvatarAccent, size: size * 0.55)
          : kIsWeb
              ? Image.network(imagePath!, fit: BoxFit.cover)
              : Image.file(File(imagePath!), fit: BoxFit.cover),
    );
  }
}
