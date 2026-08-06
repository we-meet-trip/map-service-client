import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/invite_provider.dart';

class InviteHandlerScreen extends StatefulWidget {
  const InviteHandlerScreen({super.key, required this.token});
  final String token;

  @override
  State<InviteHandlerScreen> createState() => _InviteHandlerScreenState();
}

class _InviteHandlerScreenState extends State<InviteHandlerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handle());
  }

  Future<void> _handle() async {
    final auth = context.read<AuthProvider>();
    final inviteProvider = context.read<InviteProvider>();

    // 로그인 안 된 경우: pending token 저장 후 로그인 화면으로
    if (!auth.isLoggedIn) {
      inviteProvider.pendingToken = widget.token;
      context.go('/auth');
      return;
    }

    await inviteProvider.resolveInvite(widget.token);
    if (!mounted) return;

    final status = inviteProvider.status;
    if (status == InviteStatus.success || status == InviteStatus.alreadyJoined) {
      final chatRoomId = inviteProvider.resolvedChatRoomId!;
      final rooms = await context.read<ChatRepository>().getChatRooms();
      if (!mounted) return;

      final room = rooms.where((r) => r.id == chatRoomId).firstOrNull;
      if (room != null) {
        inviteProvider.reset();
        context.go('/chat/${room.id}', extra: room);
      } else {
        inviteProvider.setError('채팅방을 찾을 수 없습니다.');
      }
    }
    // error 케이스는 build()의 Consumer에서 처리
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InviteProvider>(
      builder: (context, provider, _) {
        if (provider.status == InviteStatus.error) {
          return _ErrorView(message: provider.errorMessage ?? '유효하지 않은 링크입니다.');
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

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
