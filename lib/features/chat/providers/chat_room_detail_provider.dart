import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/chat_api_service.dart';
import '../../../core/api/chat_realtime_service.dart';
import '../../../core/api/moderation_api_service.dart';
import '../../../core/state/auth_store.dart';
import '../../../data/local/chat_outbox_store.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/repositories/api_chat_repository.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/repositories/invite_link_repository.dart';

class ChatRoomDetailProvider extends ChangeNotifier {
  ChatRoomDetailProvider(
    this._chatRepository,
    this._inviteLinkRepository,
    this.roomId, {
    ChatRealtimeService? realtime,
    ChatOutboxStore? outboxStore,
    ModerationApiService? moderation,
  }) : _realtime = realtime ?? ChatRealtimeService(),
       _store = outboxStore ?? ChatOutboxStore(roomId),
       _moderation = moderation ?? ModerationApiService.instance,
       _sessionVersion = AuthStore.instance.sessionVersion,
       _userId = AuthStore.instance.userId;

  final ChatRepository _chatRepository;
  final InviteLinkRepository _inviteLinkRepository;
  final ChatRealtimeService _realtime;
  final ChatOutboxStore _store;
  final ModerationApiService _moderation;
  Set<int> _blockedUserIds = {};
  final Set<int> _removedMessageSeqs = {};
  int _historyVersion = 0;
  final int _sessionVersion;
  final int? _userId;
  final int roomId;
  StreamSubscription<ChatEvent>? _eventSub;
  StreamSubscription<ChatConnectionState>? _stateSub;
  StreamSubscription<void>? _reconnectSub;
  Timer? _retry;
  bool _disposed = false;
  bool _flushing = false;
  Future<void>? _restoring;
  final List<PendingChatMessage> _outbox = [];
  static const _maxOutbox = 20;
  int _sendSeq = 0;
  List<ChatMessage> _messages = [];
  bool isLoading = false;
  String? realtimeNotice;
  String? _sendError;
  bool isReadOnly = false;
  InviteLink? _inviteLink;

  bool get _active =>
      !_disposed && _sessionVersion == AuthStore.instance.sessionVersion;
  List<ChatMessage> get messages =>
      _messages.where(_visible).toList(growable: false);
  bool _visible(ChatMessage message) =>
      !_blockedUserIds.contains(message.senderId) &&
      !_removedMessageSeqs.contains(message.seq);

  /// Refresh server history after changing visibility. A stale in-flight request
  /// must not put blocked/removed content back into the local conversation.
  Future<void> refreshBlocks({bool reloadHistory = true}) async {
    final version = _historyVersion;
    final blocked = await _moderation.blocks();
    if (!_active || version != _historyVersion) return;
    _blockedUserIds = blocked.map((user) => user.userId).toSet();
    _messages.removeWhere((message) => !_visible(message));
    _historyVersion++;
    _notify();
    if (reloadHistory) await loadMessages(replaceConfirmed: true);
  }

  Future<void> blockUser(int userId) async {
    if (!_active || userId <= 0 || userId == _userId) return;
    await _moderation.block(userId);
    if (!_active) return;
    _blockedUserIds.add(userId);
    _messages.removeWhere((message) => !_visible(message));
    _historyVersion++;
    _notify();
    try {
      await loadMessages(replaceConfirmed: true);
    } catch (_) {
      realtimeNotice = '차단했어요. 대화 기록은 연결이 회복되면 다시 확인할게요.';
      _notify();
    }
  }

  bool get hasUnsent => _outbox.isNotEmpty;

  void _notify() {
    if (_active) notifyListeners();
  }

  Future<void> _restore() async {
    final pending = _restoring ??= () async {
      final held = await _store.load();
      if (!_active) return;
      _outbox.addAll(held);
      _messages.addAll(held.map(_optimistic));
    }();
    try {
      await pending;
    } catch (_) {
      if (identical(_restoring, pending)) _restoring = null;
      rethrow;
    }
  }

  ChatMessage _optimistic(PendingChatMessage m) => ChatMessage(
    roomId: roomId,
    seq: 0,
    senderId: _userId,
    senderName: '나',
    text: m.text,
    sentAt: m.createdAt,
    isMe: true,
    clientMsgId: m.clientMsgId,
    pending: true,
  );

  Future<void> open({required bool readOnly}) async {
    isReadOnly = readOnly;
    try {
      await _restore();
      await loadMessages();
    } catch (_) {
      realtimeNotice = '대화 기록을 불러오지 못했어요. 연결되면 다시 확인할게요.';
      _notify();
    }
    // REST 실패가 실시간 연결의 복구까지 막지 않게 한다.
    if (!_active || isReadOnly) return;
    _eventSub ??= _realtime.events.listen(_onEvent);
    _stateSub ??= _realtime.states.listen(_onState);
    _reconnectSub ??= _realtime.reconnected.listen((_) => unawaited(_reload()));
    _realtime.connect(roomId);
  }

  Future<void> loadMessages({bool replaceConfirmed = false}) async {
    if (!_active) return;
    final version = _historyVersion;
    final beforeLoad = _messages
        .where((m) => !m.pending)
        .map((m) => m.seq)
        .toSet();
    isLoading = true;
    _notify();
    try {
      final loaded = await _chatRepository.getMessages(roomId);
      if (!_active || version != _historyVersion) return;
      final confirmed = loaded
          .where((m) => m.isMe && m.clientMsgId != null)
          .map((m) => m.clientMsgId)
          .toSet();
      _outbox.removeWhere((m) => confirmed.contains(m.clientMsgId));
      await _store.save(List.of(_outbox));
      if (!_active || version != _historyVersion) return;
      final bySeq = {for (final m in loaded.where(_visible)) m.seq: m};
      // 조회가 진행되는 동안 받은 소켓/전송 확인도 보존한다.
      for (final m in _messages.where(
        (m) =>
            !m.pending &&
            m.seq > 0 &&
            _visible(m) &&
            (!replaceConfirmed || !beforeLoad.contains(m.seq)),
      )) {
        bySeq.putIfAbsent(m.seq, () => m);
      }
      _messages = [...bySeq.values, ..._outbox.map(_optimistic)]
        ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
      final latest = loaded.fold<int>(0, (seq, m) => m.seq > seq ? m.seq : seq);
      if (latest > 0 && !isReadOnly) {
        await _chatRepository.markAsRead(roomId, latest);
      }
    } finally {
      isLoading = false;
      _notify();
    }
  }

  Future<void> _reload() async {
    try {
      await loadMessages();
    } catch (_) {
      /* 다음 재연결에서 다시 조회한다. */
    }
  }

  void _onState(ChatConnectionState state) {
    if (!_active) {
      _realtime.disconnect();
      return;
    }
    if (state == ChatConnectionState.connected) unawaited(_flushOutbox());
    realtimeNotice = switch (state) {
      ChatConnectionState.authRequired => '로그인이 필요해요.',
      ChatConnectionState.disconnected => '연결이 끊어졌어요. 다시 연결 중이에요.',
      _ => null,
    };
    _notify();
  }

  void _onEvent(ChatEvent event) {
    if (!_active) return;
    if (event.roomId != null && event.roomId != roomId) return;
    switch (event.kind) {
      case ChatEventKind.messageRemoved:
        final seq = event.data?['seq'];
        if (seq is int && seq > 0) {
          _removedMessageSeqs.add(seq);
          _messages.removeWhere((message) => message.seq == seq);
          _historyVersion++;
          _notify();
          unawaited(_reload());
        }
      case ChatEventKind.message:
      case ChatEventKind.system:
        final data = event.data;
        final repo = _chatRepository;
        if (data != null && repo is ApiChatRepository) {
          _accept(repo.fromEvent(ChatMessageResponse.fromJson(data)));
          unawaited(_persistAcknowledged());
        }
      case ChatEventKind.read:
        unawaited(_reload());
      case ChatEventKind.roomClosed:
        isReadOnly = true;
        _retry?.cancel();
        realtimeNotice = '보관된 채팅방이에요. 보낼 수 없는 메시지는 확인해주세요.';
        _realtime.disconnect();
        _notify();
      case ChatEventKind.error:
        _sendError = event.reason ?? '메시지를 보내지 못했어요.';
        _notify();
      case ChatEventKind.typing:
      case ChatEventKind.presence:
      case ChatEventKind.unknown:
        break;
    }
  }

  Future<void> _persistAcknowledged() async {
    try {
      await _store.save(List.of(_outbox));
    } catch (_) {
      /* 재시작 후 같은 ID를 재전송해 서버에서 중복을 제거한다. */
    }
  }

  void _accept(ChatMessage saved) {
    if (!_active) return;
    if (!_visible(saved)) return;
    if (saved.isMe && saved.clientMsgId != null) {
      _outbox.removeWhere((m) => m.clientMsgId == saved.clientMsgId);
    }
    _messages = [
      ..._messages.where(
        (m) =>
            !(m.pending && m.clientMsgId == saved.clientMsgId) &&
            !(m.seq > 0 && m.seq == saved.seq),
      ),
      saved,
    ]..sort((a, b) => a.sentAt.compareTo(b.sentAt));
    _notify();
  }

  String? consumeSendError() {
    final error = _sendError;
    _sendError = null;
    return error;
  }

  Future<void> sendMessage(String text) async {
    if (!_active || isReadOnly || text.trim().isEmpty) return;
    try {
      await _restore();
      if (!_active) return;
      if (_outbox.length >= _maxOutbox) {
        _sendError = '아직 전송되지 않은 메시지가 많아요. 연결 후 다시 보내주세요.';
        _notify();
        return;
      }
      final id =
          'c-${_userId ?? 0}-${_sendSeq++}-${DateTime.now().microsecondsSinceEpoch}';
      final item = PendingChatMessage(text, id, DateTime.now());
      _outbox.add(item);
      try {
        await _store.save(List.of(_outbox));
      } catch (_) {
        _outbox.remove(item);
        rethrow;
      }
      if (!_active) return;
      _messages = [..._messages, _optimistic(item)];
      _notify();
      await _flushOutbox();
    } catch (_) {
      _sendError = '메시지를 기기에 보관하지 못했어요. 다시 시도해주세요.';
      _notify();
    }
  }

  Future<void> _flushOutbox() async {
    if (_flushing || !_active || isReadOnly) return;
    _flushing = true;
    _retry?.cancel();
    try {
      while (_outbox.isNotEmpty && _active && !isReadOnly) {
        final held = _outbox.first;
        try {
          // REST 응답은 저장 완료 확인이다. 소켓 send 성공만으로 큐를 비우지 않는다.
          final saved = await _chatRepository.sendMessage(
            roomId,
            held.text,
            held.clientMsgId,
          );
          if (!_active) return;
          _accept(saved);
          _outbox.removeWhere((m) => m.clientMsgId == held.clientMsgId);
          await _store.save(List.of(_outbox));
        } on ApiException catch (e) {
          if (!_active) return;
          if (e.statusCode >= 400 &&
              e.statusCode < 500 &&
              e.statusCode != 408 &&
              e.statusCode != 429) {
            _outbox.removeWhere((m) => m.clientMsgId == held.clientMsgId);
            _messages.removeWhere(
              (m) => m.pending && m.clientMsgId == held.clientMsgId,
            );
            await _store.save(List.of(_outbox));
            _sendError = e.message;
            if (e.statusCode == 401 || e.statusCode == 403) {
              isReadOnly = true;
              break;
            }
            continue;
          }
          break;
        } catch (_) {
          break;
        }
      }
    } finally {
      _flushing = false;
      _notify();
      if (_outbox.isNotEmpty && _active && !isReadOnly) {
        _retry = Timer(
          const Duration(seconds: 3),
          () => unawaited(_flushOutbox()),
        );
      }
    }
  }

  Future<InviteLink> getInviteLink() async {
    final cached = _inviteLink;
    if (cached != null &&
        (cached.expiresAt == null ||
            cached.expiresAt!.isAfter(DateTime.now()))) {
      return cached;
    }
    final issued = await _inviteLinkRepository.generateInviteLink(roomId);
    if (_active) _inviteLink = issued;
    return issued;
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _eventSub?.cancel();
    _stateSub?.cancel();
    _reconnectSub?.cancel();
    _realtime.dispose();
    super.dispose();
  }
}
