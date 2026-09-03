import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/utils/support_mail.dart';
import '../../../common/widgets/app_confirm_dialog.dart';
import '../../../core/state/auth_store.dart';
import '../../../core/state/trip_repository.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/chat_room.dart';
import '../../../data/repositories/chat_repository.dart';
import '../providers/chat_room_detail_provider.dart';
import '../providers/chat_room_list_provider.dart';
import 'chat_room_missing_screen.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_detail_header.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/chat_room_menu_sheet.dart';
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

  /// 방 메뉴를 연다. 참가자 목록에서 내가 방장인지 판별해 '내보내기'를
  /// 방장에게만 보여준다.
  Future<void> _showMenuSheet() async {
    final repository = context.read<ChatRepository>();
    List<ChatUser> participants = const [];
    try {
      participants = await repository.getParticipants(widget.roomId);
    } catch (_) {
      // 참가자를 못 받아도 나가기·신고는 가능해야 하므로 시트는 연다.
      // 방장 판별만 못 하니 '내보내기'가 빠질 뿐이다.
    }
    if (!mounted) return;
    final me = AuthStore.instance.userId;
    final isOwner =
        me != null && participants.any((p) => p.userId == me && p.isOwner);

    setState(() => _isSheetOpen = true);
    await showModalBottomSheet<void>(
      context: context,
      barrierColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => ChatRoomMenuSheet(
        onLeave: () {
          Navigator.of(sheetContext).pop();
          _confirmLeave(isOwner: isOwner);
        },
        onReport: () {
          Navigator.of(sheetContext).pop();
          _reportRoom();
        },
        onKick: isOwner
            ? () {
                Navigator.of(sheetContext).pop();
                _showKickSheet(participants);
              }
            : null,
      ),
    );
    if (mounted) setState(() => _isSheetOpen = false);
  }

  /// 확인을 받고 방에서 나간다. 방장이 나가면 서버가 방을 종료하므로
  /// 확인 문구부터 다르게 보여준다.
  Future<void> _confirmLeave({required bool isOwner}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppConfirmDialog(
        content: Text(
          isOwner
              ? '방장이 나가면 방이 종료됩니다.\n채팅방을 나갈까요?'
              : '채팅방을 나갈까요?',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1C1C28),
          ),
        ),
        confirmLabel: '나가기',
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (ok != true || !mounted) return;

    final listProvider = context.read<ChatRoomListProvider>();
    try {
      await context.read<ChatRepository>().leave(widget.roomId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('채팅방을 나가지 못했어요. 잠시 후 다시 시도해주세요.')),
        );
      }
      return;
    }
    // 목록 갱신이 실패해도 나가기 자체는 이미 끝났으므로 이동은 막지 않는다.
    try {
      await listProvider.loadRooms();
    } catch (_) {}
    if (mounted) context.go('/chat');
  }

  /// 신고는 메일 양식으로 받는다. 빈칸은 사용자가 채워 보낸다.
  void _reportRoom() {
    launchSupportMail(
      subject: '[MAP 신고] 채팅방 ${widget.roomId}',
      body: '방 제목: ${_current?.title ?? ''}\n'
          '신고 대상: \n'
          '신고 사유: \n'
          '발생 시각: \n',
    );
  }

  /// 내보낼 수 있는 사람: 아직 방에 있고 내가 아닌 참가자.
  static List<ChatUser> _kickable(List<ChatUser> participants, int? me) =>
      participants.where((p) => p.isActive && p.userId != me).toList();

  /// 방장이 참가자를 내보내는 시트. 내보낸 뒤 목록을 다시 받아 그린다.
  /// 방장 여부의 최종 판정은 서버가 하므로 거절되면 안내만 띄운다.
  Future<void> _showKickSheet(List<ChatUser> participants) async {
    final repository = context.read<ChatRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final me = AuthStore.instance.userId;
    var candidates = _kickable(participants, me);

    setState(() => _isSheetOpen = true);
    await showModalBottomSheet<void>(
      context: context,
      barrierColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Container(
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            16 + MediaQuery.of(sheetContext).padding.bottom,
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
              const SizedBox(height: 16),
              const Text(
                '내보내기',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1C1C28),
                ),
              ),
              const SizedBox(height: 8),
              if (candidates.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    '내보낼 참가자가 없어요',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.neutralScale[300],
                    ),
                  ),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final p in candidates)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () async {
                              try {
                                await repository.kick(widget.roomId, p.userId);
                                final refreshed = await repository
                                    .getParticipants(widget.roomId);
                                if (!sheetContext.mounted) return;
                                setSheetState(() =>
                                    candidates = _kickable(refreshed, me));
                              } catch (_) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('내보내지 못했어요. 잠시 후 다시 시도해주세요.'),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              alignment: Alignment.center,
                              child: Text(
                                p.nickname,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1C1C28),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
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
              // 지난 방에서도 나가기·신고는 해야 하므로 조건 없이 연다.
              onMenu: _showMenuSheet,
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
