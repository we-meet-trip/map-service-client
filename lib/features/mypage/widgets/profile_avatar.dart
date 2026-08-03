import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
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
      // 고른 사진을 가리키는 방식이 환경마다 다르다. 기기에서는 파일 경로가
      // 오지만 브라우저에서는 주소 형태로 오며, 브라우저에는 파일을 직접
      // 여는 수단이 없어 파일로 열려 하면 그 자리에서 죽는다.
      child: imagePath == null
          ? Icon(Icons.person_rounded, color: AppColors.mypageAvatarAccent, size: size * 0.55)
          : kIsWeb
              ? Image.network(imagePath!, fit: BoxFit.cover)
              : Image.file(File(imagePath!), fit: BoxFit.cover),
    );
  }
}
