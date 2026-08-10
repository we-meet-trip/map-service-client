import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/next_button.dart';
import '../../../data/repositories/invite_link_repository.dart';
import '../providers/chat_room_detail_provider.dart';

class InviteLinkBottomSheet extends StatefulWidget {
  const InviteLinkBottomSheet({super.key, required this.roomTitle});
  final String roomTitle;

  @override
  State<InviteLinkBottomSheet> createState() => _InviteLinkBottomSheetState();
}

class _InviteLinkBottomSheetState extends State<InviteLinkBottomSheet> {
  InviteLink? _link;
  String? _error;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final link = await context.read<ChatRoomDetailProvider>().getInviteLink();
      if (mounted) setState(() => _link = link);
    } catch (e) {
      // 여기서 그냥 두면 진행 막대가 영영 돌아가 사용자가 기다리기만 한다.
      if (mounted) {
        setState(() => _error = '링크를 만들지 못했어요. 잠시 후 다시 시도해주세요.');
      }
    }
  }

  Future<void> _copyLink() async {
    final link = _link;
    if (link == null) return;
    await Clipboard.setData(ClipboardData(text: link.url));
    if (mounted) setState(() => _copied = true);
  }

  /// 남은 유효기간 문구. 서버가 준 만료 시각에서 계산한다.
  ///
  /// 며칠인지를 붙박이로 적어 두면 방이 링크보다 먼저 닫히는 일정에서 그대로
  /// 거짓이 된다. 서버가 이미 둘 중 이른 쪽을 실어 주므로 그대로 쓴다.
  String _validityLabel() {
    final expiry = _link?.expiresAt;
    if (expiry == null) return '';
    final left = expiry.difference(DateTime.now());
    if (left.isNegative) return '만료됨';
    if (left.inHours < 24) return '오늘까지';
    return '${left.inDays + 1}일간';
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
                  child: _error != null
                      ? Text(
                          _error!,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.neutralScale[400],
                          ),
                        )
                      : _link == null
                          ? const LinearProgressIndicator()
                          : Text(
                              _link!.url,
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
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              '채팅방으로 이동',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.neutralScale[500],
              ),
            ),
          ),
          const SizedBox(height: 4),
          if (_link?.expiresAt != null)
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: '⏳  이 링크는 '),
                  TextSpan(
                    text: _validityLabel(),
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
