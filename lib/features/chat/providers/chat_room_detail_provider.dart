import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/chat_realtime_service.dart';
import '../../../core/state/auth_store.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/repositories/api_chat_repository.dart';
import '../../../data/repositories/api_invite_repository.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/repositories/invite_link_repository.dart';

class ChatRoomDetailProvider extends ChangeNotifier {
  ChatRoomDetailProvider(
      this._chatRepository, this._inviteLinkRepository, this.roomId);

  final ChatRepository _chatRepository;
  final InviteLinkRepository _inviteLinkRepository;
  final String roomId;

  List<ChatMessage> _messages = [];
  bool isLoading = false;

  /// 실시간 연결이 거절되었거나 끊어진 사유. 화면이 안내에 쓴다.
  String? realtimeNotice;

  /// 보관 상태로 넘어간 방. 입력창을 닫아야 한다.
  bool isReadOnly = false;

  String? _inviteLink;
  DateTime? _inviteLinkExpiresAt;

  StreamSubscription<ChatEvent>? _events;

  /// 이미 화면에 있는 순번. 자기가 보낸 메시지도 방송으로 돌아오므로
  /// 이 값으로 같은 메시지를 두 번 그리지 않게 막는다. 서버가 보낸이의
  /// 임시 식별자를 돌려주지 않아 순번이 유일한 기준이다.
  final Set<String> _seenIds = {};

  List<ChatMessage> get messages => _messages;

  Future<void> loadMessages() async {
    isLoading = true;
    notifyListeners();
    try {
      _messages = await _chatRepository.getMessages(roomId);
      _seenIds
        ..clear()
        ..addAll(_messages.map((m) => m.id));
      _markReadUpToLatest();
    } on ApiException catch (e) {
      realtimeNotice = e.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
    _listenRealtime();
  }

  /// 방송을 듣기 시작한다. 보관된 방은 서버가 구독을 거절하므로 그 사유를
  /// 그대로 안내로 남기고 이력만 보여 준다.
  void _listenRealtime() {
    _events?.cancel();
    _events = ChatRealtimeService.instance.connect(roomId).listen((event) {
      switch (event.kind) {
        case ChatEventKind.message:
        case ChatEventKind.system:
          _appendFromEvent(event);
        case ChatEventKind.closed:
          isReadOnly = true;
          realtimeNotice = '보관된 대화방이에요. 새 메시지를 보낼 수 없어요.';
          notifyListeners();
        case ChatEventKind.rejected:
          isReadOnly = true;
          realtimeNotice = event.reason;
          notifyListeners();
        case ChatEventKind.disconnected:
          realtimeNotice = event.reason;
          notifyListeners();
        case ChatEventKind.connected:
          realtimeNotice = null;
          notifyListeners();
        case ChatEventKind.read:
        case ChatEventKind.typing:
        case ChatEventKind.presence:
          // 화면에 아직 표시할 자리가 없다.
          break;
      }
    });
  }

  void _appendFromEvent(ChatEvent event) {
    final data = event.data;
    if (data == null) return;
    final id = '${data['seq']}';
    if (!_seenIds.add(id)) return;
    final senderId = data['sender_id'] as int?;
    final myId = AuthStore.instance.userId;
    _messages = [
      ..._messages,
      ChatMessage(
        id: id,
        roomId: roomId,
        senderId: senderId?.toString() ?? 'system',
        senderName: data['type'] == 'SYSTEM' ? '안내' : '${senderId ?? ''}',
        text: data['content'] as String? ?? '',
        sentAt: data['created_at'] is String
            ? DateTime.tryParse(data['created_at'] as String) ?? DateTime.now()
            : DateTime.now(),
        isMe: senderId != null && myId != null && senderId == myId,
      ),
    ];
    _markReadUpToLatest();
    notifyListeners();
  }

  /// 보낸 메시지는 방송으로 돌아와 확정된다.
  ///
  /// 서버가 전송에 응답을 주지 않으므로 실시간 경로로 보내고, 연결이 없으면
  /// 일반 요청으로 보낸다. 어느 쪽이든 화면에 그리는 것은 돌아온 방송이다 —
  /// 미리 그려 두면 실패했을 때 보내지 못한 메시지가 남는다.
  Future<void> sendMessage(String text) async {
    if (isReadOnly) return;
    try {
      ChatRealtimeService.instance.send(roomId, text);
    } on Object {
      await _chatRepository.sendMessage(roomId, text);
    }
  }

  /// 마지막으로 받은 순번까지 읽었다고 알린다.
  void _markReadUpToLatest() {
    final last = _messages.isEmpty ? null : _messages.last.id;
    final seq = last == null ? null : int.tryParse(last);
    if (seq == null) return;
    ChatRealtimeService.instance.markRead(roomId, seq);
    final repo = _chatRepository;
    if (repo is ApiChatRepository) {
      // 실시간 연결이 없을 때를 대비해 일반 요청으로도 남긴다.
      unawaited(repo.markRead(roomId, seq).catchError((_) {}));
    }
  }

  /// 초대 링크. 서버가 준 만료 시각까지 같은 링크를 다시 쓴다.
  Future<String> getInviteLink(String roomTitle) async {
    final now = DateTime.now();
    final expires = _inviteLinkExpiresAt;
    if (_inviteLink != null && expires != null && expires.isAfter(now)) {
      return _inviteLink!;
    }
    _inviteLink =
        await _inviteLinkRepository.generateInviteLink(roomId, roomTitle);
    final repo = _inviteLinkRepository;
    // 유효 기간은 방이 살아 있는 동안이다. 임의로 정하지 않고 서버가 준
    // 시각을 쓴다.
    _inviteLinkExpiresAt = repo is ApiInviteLinkRepository
        ? repo.lastExpiresAt
        : now.add(const Duration(days: 7));
    return _inviteLink!;
  }

  /// 서버가 알려 준 초대 링크 만료 시각. 화면 안내 문구에 쓴다.
  DateTime? get inviteLinkExpiresAt => _inviteLinkExpiresAt;

  @override
  void dispose() {
    _events?.cancel();
    ChatRealtimeService.instance.disconnect();
    super.dispose();
  }
}
