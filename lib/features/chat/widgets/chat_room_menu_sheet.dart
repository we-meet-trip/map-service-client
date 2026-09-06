import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';

/// 방 메뉴 바닥 시트. 무엇을 할지는 전부 콜백으로 주입받는 순수 위젯이다.
///
/// [onKick] 이 null 이면 '내보내기' 항목을 아예 그리지 않는다 — 방장 여부는
/// 여는 쪽이 판별해서 넘긴다.
class ChatRoomMenuSheet extends StatelessWidget {
  const ChatRoomMenuSheet({
    super.key,
    required this.onLeave,
    required this.onReport,
    this.onKick,
  });

  final VoidCallback onLeave;
  final VoidCallback onReport;
  final VoidCallback? onKick;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.neutralScale[100],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          _MenuItem(label: '채팅방 나가기', onTap: onLeave),
          _MenuItem(label: '신고·차단 관리', onTap: onReport),
          if (onKick != null) _MenuItem(label: '내보내기', onTap: onKick!),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1C1C28),
          ),
        ),
      ),
    );
  }
}
