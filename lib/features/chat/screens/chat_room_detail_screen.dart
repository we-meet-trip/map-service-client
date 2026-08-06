import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../common/theme/app_colors.dart';
import '../../../core/state/trip_repository.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/chat_room.dart';
import '../providers/chat_room_detail_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_detail_header.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/invite_link_bottom_sheet.dart';
import '../widgets/schedule_link_button.dart';

class ChatRoomDetailScreen extends StatefulWidget {
  const ChatRoomDetailScreen({super.key, required this.room});
  final ChatRoom room;

  @override
  State<ChatRoomDetailScreen> createState() => _ChatRoomDetailScreenState();
}

class _ChatRoomDetailScreenState extends State<ChatRoomDetailScreen> {
  final _scrollController = ScrollController();
  bool _isSheetOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatRoomDetailProvider>().loadMessages().then((_) {
        _scrollToBottom();
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Color _resolveColor(ChatMessage msg) {
    final participant = widget.room.participants
        .where((p) => p.id == msg.senderId)
        .firstOrNull;
    return participant?.avatarColor ?? AppColors.avatarColors[0];
  }

  Future<void> _showInviteSheet() async {
    setState(() => _isSheetOpen = true);
    await showModalBottomSheet<void>(
      context: context,
      barrierColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<ChatRoomDetailProvider>(),
        child: InviteLinkBottomSheet(roomTitle: widget.room.title),
      ),
    );
    if (mounted) setState(() => _isSheetOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ChatDetailHeader(
              title: widget.room.title,
              participants: widget.room.participants,
              onBack: () => context.pop(),
              onShare: widget.room.type == ChatRoomType.upcoming
                  ? _showInviteSheet
                  : null,
            ),
            Expanded(
              child: Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Consumer<ChatRoomDetailProvider>(
                              builder: (context, provider, _) {
                                if (provider.isLoading) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }
                                return ListView.separated(
                                  controller: _scrollController,
                                  padding: EdgeInsets.only(
                                    left: 16,
                                    right: 16,
                                    top: 64,
                                    bottom: widget.room.type == ChatRoomType.upcoming
                                        ? 90 + MediaQuery.of(context).padding.bottom
                                        : 16,
                                  ),
                                  itemCount: provider.messages.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final msg = provider.messages[index];
                                    final color = _resolveColor(msg);
                                    return ChatBubble(message: msg, senderColor: color);
                                  },
                                );
                              },
                            ),
                            Positioned(
                                top: 12,
                                left: 0,
                                right: 0,
                                child: ScheduleLinkButton(
                                  onTap: () {
                                    final allTrips = [
                                      ...TripRepository.instance.plannedTrips.value,
                                      ...TripRepository.instance.completedTrips.value,
                                    ];
                                    final trip = allTrips
                                        .where((t) => t.id == widget.room.id)
                                        .firstOrNull;
                                    if (trip != null) {
                                      context.go('/saved/trip', extra: trip);
                                    }
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (widget.room.type == ChatRoomType.upcoming)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: ChatInputBar(
                        onSend: (text) async {
                          await context
                              .read<ChatRoomDetailProvider>()
                              .sendMessage(text);
                          _scrollToBottom();
                        },
                      ),
                    ),
                  if (_isSheetOpen)
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.28),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
