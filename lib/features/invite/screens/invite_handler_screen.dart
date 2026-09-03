import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../../../data/repositories/chat_repository.dart';
import '../providers/invite_provider.dart';

/// 초대 링크를 눌렀을 때 거치는 화면.
///
/// 순서가 중요하다. 먼저 로그인 없이 방을 확인해 무엇에 초대받았는지 보여 주고,
/// 그 다음에 로그인을 요구한다. 반대로 하면 받은 사람이 무엇인지도 모르는 채
/// 가입부터 해야 한다.
///
/// 확인을 먼저 하는 이유가 하나 더 있다. 이미 들어가 있는 사람에게 서버가 주는
/// 거절 응답에는 방 번호가 없어서, 확인해 둔 번호가 없으면 그 방으로 보낼 수 없다.
class InviteHandlerScreen extends StatefulWidget {
  const InviteHandlerScreen({super.key, required this.token});
  final String token;

  @override
  State<InviteHandlerScreen> createState() => _InviteHandlerScreenState();
}

class _InviteHandlerScreenState extends State<InviteHandlerScreen> {
  /// 방은 확인했지만 아직 로그인하지 않은 상태.
  bool _needsLogin = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handle());
  }

  Future<void> _handle() async {
    final invite = context.read<InviteProvider>();

    final joinable = await invite.loadPreview(widget.token);
    if (!mounted) return;
    if (invite.status == InviteStatus.error) return;

    if (!isAuthenticated.value) {
      // 로그인부터 시키지 않고 무엇에 초대받았는지 먼저 보여 준다. 미리보기가
      // 무인증으로 열려 있어 이미 손에 쥔 정보이고, 모르는 채 가입부터 하게
      // 만들면 대부분 거기서 멈춘다. 로그인은 사용자가 누를 때 간다.
      setState(() => _needsLogin = true);
      return;
    }

    if (!joinable) return;

    await invite.join(widget.token);
    if (!mounted) return;

    switch (invite.status) {
      case InviteStatus.success:
      case InviteStatus.alreadyJoined:
        await _enterRoom(invite);
      case InviteStatus.loginRequired:
        context.go('/auth');
      default:
        break;
    }
  }

  Future<void> _enterRoom(InviteProvider invite) async {
    final roomId = invite.resolvedChatRoomId;
    if (roomId == null) {
      invite.setError('채팅방을 찾을 수 없어요.');
      return;
    }
    try {
      // 목록을 통째로 훑지 않고 번호로 곧장 가져온다.
      final room = await context.read<ChatRepository>().getRoom(roomId);
      if (!mounted) return;
      invite.reset();
      context.go('/chat/$roomId', extra: room);
    } catch (_) {
      if (mounted) invite.setError('채팅방을 여는 데 실패했어요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InviteProvider>(
      builder: (context, provider, _) {
        if (provider.status == InviteStatus.error) {
          return _ErrorView(message: provider.errorMessage ?? '유효하지 않은 링크입니다.');
        }
        // 들어갈 수 없는 링크라도 무엇에 초대받았는지는 알려 준다.
        if (provider.status == InviteStatus.preview && provider.errorMessage != null) {
          return _ErrorView(
            title: provider.roomTitle,
            message: provider.errorMessage!,
          );
        }
        if (_needsLogin) {
          return _InviteIntroView(
            title: provider.roomTitle ?? '여행 채팅방',
            participantCount: provider.participantCount,
            expiresAt: provider.expiresAt,
            onLogin: () {
              // 로그인이 끝나면 앱이 이 토큰으로 여기까지 다시 데려온다.
              provider.pendingToken = widget.token;
              context.go('/auth');
            },
          );
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

/// 로그인 전에 보여 주는 초대 안내.
///
/// 브라우저로 열었을 때 보는 안내 페이지와 같은 것을 보여 준다. 앱에서만
/// 아무 설명 없이 로그인부터 요구하면 같은 링크인데 경로에 따라 대접이 달라진다.
class _InviteIntroView extends StatelessWidget {
  const _InviteIntroView({
    required this.title,
    required this.onLogin,
    this.participantCount,
    this.expiresAt,
  });

  final String title;
  final int? participantCount;
  final DateTime? expiresAt;
  final VoidCallback onLogin;

  String get _meta {
    final bits = <String>[];
    if (participantCount != null) bits.add('현재 $participantCount명 참여 중');
    final until = expiresAt;
    if (until != null) {
      final left = until.difference(DateTime.now());
      if (!left.isNegative) {
        bits.add(left.inHours < 24 ? '오늘까지 유효' : '${left.inDays + 1}일간 유효');
      }
    }
    return bits.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('✉️', style: TextStyle(fontSize: 44)),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1C28),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  '함께할 사람으로 초대받았어요.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF8F8E90)),
                  textAlign: TextAlign.center,
                ),
                if (_meta.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    _meta,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF8F8E90)),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onLogin,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1C1C28),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '로그인하고 참가하기',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, this.title});

  final String message;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('😕', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                if (title != null) ...[
                  Text(
                    title!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C1C28),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1C1C28),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  '초대 링크가 만료되었거나 올바르지 않습니다.\n새 링크를 요청해 주세요.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF8F8E90)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextButton(
                  onPressed: () => context.go('/'),
                  child: const Text('홈으로 돌아가기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
