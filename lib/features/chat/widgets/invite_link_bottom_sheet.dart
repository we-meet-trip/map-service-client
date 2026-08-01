import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/next_button.dart';
import '../providers/chat_room_detail_provider.dart';

class InviteLinkBottomSheet extends StatefulWidget {
  const InviteLinkBottomSheet({super.key, required this.roomTitle});
  final String roomTitle;

  @override
  State<InviteLinkBottomSheet> createState() => _InviteLinkBottomSheetState();
}

class _InviteLinkBottomSheetState extends State<InviteLinkBottomSheet> {
  String? _link;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    context
        .read<ChatRoomDetailProvider>()
        .getInviteLink(widget.roomTitle)
        .then((link) {
      if (mounted) setState(() => _link = link);
    });
  }

  Future<void> _copyLink() async {
    if (_link == null) return;
    await Clipboard.setData(ClipboardData(text: _link!));
    if (mounted) setState(() => _copied = true);
  }

  /// 서버가 알려 준 만료 시각을 사람이 읽는 표기로 바꾼다.
  ///
  /// 아직 링크를 받기 전이거나 서버가 시각을 주지 않았으면 기간을 단정하지
  /// 않는다.
  String _expiryLabel() {
    final at = context.read<ChatRoomDetailProvider>().inviteLinkExpiresAt;
    if (at == null) return '여행이 끝날 때까지';
    final local = at.toLocal();
    return '${local.year}년 ${local.month}월 ${local.day}일까지';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
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
          const SizedBox(height: 24),
          PhosphorIcon(
            PhosphorIconsRegular.envelope,
            size: 40,
            color: AppColors.shareIcon,
          ),
          const SizedBox(height: 12),
          const Text(
            '채팅방 초대하기',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1C28),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '아래 링크를 공유하여 ${widget.roomTitle}에 친구를 초대하세요',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.neutralScale[300],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.neutralScale[0],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.neutralScale[100]!),
            ),
            child: Row(
              children: [
                PhosphorIcon(
                  PhosphorIconsRegular.link,
                  size: 16,
                  color: AppColors.shareIcon,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _link == null
                      ? const LinearProgressIndicator()
                      : Text(
                          _link!,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.neutralScale[400],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          NextButton(
            label: _copied ? '복사됨!' : '링크 복사하기',
            onPressed: _link != null ? _copyLink : null,
          ),
          const SizedBox(height: 14),
          // 유효 기간은 서버가 정한다 — 방이 살아 있는 동안이며, 링크를
          // 새로 만들면 이전 링크는 그 자리에서 죽는다. 화면이 임의의
          // 기간을 적으면 실제와 어긋난 안내가 된다.
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: '⏳  이 링크는 '),
                TextSpan(
                  text: _expiryLabel(),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutralScale[500],
                  ),
                ),
                const TextSpan(text: ' 유효합니다'),
              ],
              style: TextStyle(
                fontSize: 12,
                color: AppColors.neutralScale[300],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
