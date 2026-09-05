import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../common/theme/app_colors.dart';
import '../../../core/state/user_repository.dart';
import '../../../data/models/user.dart';
import '../../mypage/widgets/profile_avatar.dart';

class ChatDetailHeader extends StatelessWidget {
  const ChatDetailHeader({
    super.key,
    required this.title,
    required this.participants,
    required this.onBack,
    this.onShare,
    this.onMenu,
  });

  final String title;
  final List<User> participants;
  final VoidCallback onBack;
  final VoidCallback? onShare;
  final VoidCallback? onMenu;

  List<User> get _allParticipants {
    final me = UserRepository.instance.profile.value;
    return [
      User(id: me.id, name: me.nickname.isEmpty ? '나' : me.nickname),
      ...participants,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: PhosphorIcon(
                  PhosphorIconsRegular.caretLeft,
                  size: 24,
                  color: const Color(0xFF1C1C28),
                ),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1C28),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    _ParticipantAvatars(participants: _allParticipants),
                  ],
                ),
              ),
              if (onShare != null)
                GestureDetector(
                  onTap: onShare,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFFFFF),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: PhosphorIcon(
                        PhosphorIconsRegular.shareNetwork,
                        size: 20,
                        color: AppColors.shareIcon,
                      ),
                    ),
                  ),
                ),
              if (onShare != null && onMenu != null) const SizedBox(width: 8),
              if (onMenu != null)
                GestureDetector(
                  onTap: onMenu,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFFFFF),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: PhosphorIcon(
                        PhosphorIconsRegular.dotsThreeVertical,
                        size: 20,
                        color: AppColors.shareIcon,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
      ],
    );
  }
}

class _ParticipantAvatars extends StatelessWidget {
  const _ParticipantAvatars({required this.participants});
  final List<User> participants;

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) return const SizedBox.shrink();
    final displayCount = participants.length.clamp(1, 3);
    const diameter = 20.0;
    const overlap = 8.0;
    final totalWidth = diameter + (displayCount - 1) * (diameter - overlap);

    return SizedBox(
      height: diameter,
      width: totalWidth,
      child: Stack(
        children: [
          for (int i = 0; i < displayCount; i++)
            Positioned(
              left: i * (diameter - overlap),
              child: ProfileAvatar(
                size: diameter,
                color: AppColors.avatarColorOf(participants[i].id),
              ),
            ),
        ],
      ),
    );
  }
}
