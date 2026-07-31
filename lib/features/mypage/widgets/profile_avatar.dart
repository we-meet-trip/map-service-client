import 'dart:io';
import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';

/// 프로필 사진 아바타. [imagePath]가 없으면 기본 아이콘을 보여준다.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.imagePath, this.size = 56});

  final String? imagePath;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.37),
        color: AppColors.mypageAvatarAccent.withAlpha(77),
      ),
      clipBehavior: Clip.antiAlias,
      child: imagePath != null
          ? Image.file(File(imagePath!), fit: BoxFit.cover)
          : Icon(Icons.person_rounded, color: AppColors.mypageAvatarAccent, size: size * 0.55),
    );
  }
}
