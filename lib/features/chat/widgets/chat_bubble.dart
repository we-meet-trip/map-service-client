import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';
import '../../../data/models/chat_message.dart';
import '../../mypage/widgets/profile_avatar.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    this.senderColor = AppColors.mypageAvatarAccent,
  });
  final ChatMessage message;
  final Color senderColor;

  @override
  Widget build(BuildContext context) {
    // 안내는 사람이 한 말이 아니다. 말풍선으로 그리면 아무도 없는 자리에
    // 아바타와 이름이 생겨, 누가 한 말인지 찾게 만든다.
    if (message.type == ChatMessageType.system) {
      return _SystemNotice(text: message.text);
    }
    return message.isMe
        ? _MyBubble(message: message)
        : _OtherBubble(message: message, senderColor: senderColor);
  }
}

/// 서버가 남긴 안내. 가운데 한 줄로 흘려보낸다.
class _SystemNotice extends StatelessWidget {
  const _SystemNotice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppColors.neutralScale[400],
          ),
        ),
      ),
    );
  }
}

/// 아직 안 읽은 사람 수. 아무도 안 남았으면 자리를 차지하지 않는다.
class _UnreadCount extends StatelessWidget {
  const _UnreadCount({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.senderName,
        ),
      ),
    );
  }
}

class _MyBubble extends StatelessWidget {
  const _MyBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _UnreadCount(count: message.unreadCount),
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.65,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.myBubbleBg,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
          ),
          // 아직 서버가 받았다고 알려 주지 않은 동안은 옅게 덮어 둔다.
          foregroundDecoration: message.pending
              ? BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.35),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(4),
                  ),
                )
              : null,
          child: Text(
            message.text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.myBubbleText,
            ),
          ),
        ),
      ],
    );
  }
}

class _OtherBubble extends StatelessWidget {
  const _OtherBubble({required this.message, required this.senderColor});
  final ChatMessage message;
  final Color senderColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileAvatar(size: 32, color: senderColor),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.senderName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.senderName,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.65,
                      ),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: const BoxDecoration(
                        color: AppColors.otherBubbleBg,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(18),
                          bottomLeft: Radius.circular(18),
                          bottomRight: Radius.circular(18),
                        ),
                      ),
                      child: Text(
                        message.text,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: AppColors.otherBubbleText,
                        ),
                      ),
                    ),
                  ),
                  _UnreadCount(count: message.unreadCount),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
