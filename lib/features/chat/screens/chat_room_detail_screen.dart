import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../data/models/chat_room.dart';
import '../providers/chat_room_detail_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_detail_header.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/schedule_link_button.dart';

class ChatRoomDetailScreen extends StatefulWidget {
  const ChatRoomDetailScreen({super.key, required this.room});
  final ChatRoom room;

  @override
  State<ChatRoomDetailScreen> createState() => _ChatRoomDetailScreenState();
}

class _ChatRoomDetailScreenState extends State<ChatRoomDetailScreen> {
  final _scrollController = ScrollController();

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
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
              participantCount: widget.room.participantCount,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: Stack(
                children: [
                  Consumer<ChatRoomDetailProvider>(
                    builder: (context, provider, _) {
                      if (provider.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return ListView.separated(
                        controller: _scrollController,
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: widget.room.linkedTripId != null ? 64 : 16,
                          bottom: 16,
                        ),
                        itemCount: provider.messages.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) =>
                            ChatBubble(message: provider.messages[index]),
                      );
                    },
                  ),
                  if (widget.room.linkedTripId != null)
                    const Positioned(
                      top: 12,
                      left: 0,
                      right: 0,
                      child: ScheduleLinkButton(),
                    ),
                ],
              ),
            ),
            ChatInputBar(
              onSend: (text) async {
                await context.read<ChatRoomDetailProvider>().sendMessage(text);
                _scrollToBottom();
              },
            ),
          ],
        ),
      ),
    );
  }
}
