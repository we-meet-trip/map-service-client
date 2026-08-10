import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../common/theme/app_colors.dart';
import '../../../core/state/trip_repository.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/chat_room.dart';
import '../../../data/repositories/chat_repository.dart';
import '../providers/chat_room_detail_provider.dart';
import 'chat_room_missing_screen.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_detail_header.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/invite_link_bottom_sheet.dart';
import '../widgets/schedule_link_button.dart';

/// 방 하나를 여는 화면.
///
/// [room] 은 목록에서 눌러 들어왔을 때만 채워진다. 링크로 곧장 들어오거나
/// 브라우저에서 새로 고치면 없으므로, 그때는 번호로 직접 받아 온다.
class ChatRoomDetailScreen extends StatefulWidget {
  const ChatRoomDetailScreen({super.key, required this.roomId, this.room});

  final int roomId;
  final ChatRoom? room;

  @override
  State<ChatRoomDetailScreen> createState() => _ChatRoomDetailScreenState();
}

class _ChatRoomDetailScreenState extends State<ChatRoomDetailScreen> {
  final _scrollController = ScrollController();
  bool _isSheetOpen = false;
  ChatRoomDetailProvider? _provider;
  ChatRoom? _room;

  /// 방을 받아 오지 못한 상태. 없는 방이거나 내가 못 들어가는 방이다.
  bool _missing = false;

  ChatRoom? get _current => _room ?? widget.room;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (!mounted) return;
    final provider = context.read<ChatRoomDetailProvider>();
    _provider = provider;
    provider.addListener(_showSendErrorIfAny);

    var room = widget.room;
    if (room == null) {
      try {
        room = await context.read<ChatRepository>().getRoom(widget.roomId);
      } catch (_) {
        // 방을 못 받았다는 것은 없는 방이거나 내가 못 들어가는 방이라는 뜻이다.
        // 그대로 두면 제목도 대화도 없는 빈 껍데기가 떠서, 사용자는 방이 비어
        // 있는 것인지 열리다 만 것인지 알 수 없다.
        if (mounted) setState(() => _missing = true);
        return;
      }
      if (!mounted) return;
      setState(() => _room = room);
    }

    await provider.open(readOnly: room.readOnly);
    if (mounted) _scrollToBottom();
  }

  @override
  void dispose() {
    _provider?.removeListener(_showSendErrorIfAny);
    _scrollController.dispose();
    super.dispose();
  }

  /// 전송이 서버에서 거절되면 사유를 스낵바로 한 번 보여준다. 보낸 메시지는
  /// 방송이 돌아와야 그려지므로, 이 안내가 없으면 실패를 알 길이 없다.
  void _showSendErrorIfAny() {
    final error = _provider?.consumeSendError();
    if (error == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
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

  /// 아직 다닐 여행의 방인지. 방을 아직 못 받았으면 입력창을 열어 두지 않는다.
  bool get _isUpcoming => _current?.type == ChatRoomType.upcoming;

  // 안내 메시지는 보낸 사람이 없어 색을 뽑을 값이 없다.
  Color _resolveColor(ChatMessage msg) =>
      AppColors.avatarColorOf(msg.senderId?.toString() ?? 'system');

  Future<void> _showInviteSheet() async {
    setState(() => _isSheetOpen = true);
    await showModalBottomSheet<void>(
      context: context,
      barrierColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<ChatRoomDetailProvider>(),
        child: InviteLinkBottomSheet(roomTitle: _current?.title ?? '채팅방'),
      ),
    );
    if (mounted) setState(() => _isSheetOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_missing) return const ChatRoomMissingScreen();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ChatDetailHeader(
              title: _current?.title ?? '채팅방',
              participants: _current?.participants ?? const [],
              onBack: () => context.pop(),
              onShare: _isUpcoming ? _showInviteSheet : null,
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
                                    bottom: _isUpcoming
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
                                    final scheduleId = _current?.scheduleId;
                                    final trip = allTrips
                                        .where((t) => t.scheduleId == scheduleId)
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
                  if (_isUpcoming)
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
