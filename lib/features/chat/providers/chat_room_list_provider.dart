import 'package:flutter/foundation.dart';
import '../../../core/api/api_client.dart';
import '../../../data/models/chat_room.dart';
import '../../../data/repositories/api_chat_repository.dart';
import '../../../data/repositories/chat_repository.dart';
import '../models/chat_room.dart';

class ChatRoomListProvider extends ChangeNotifier {
  ChatRoomListProvider(this._repository);

  final ChatRepository _repository;

  ChatRoomFilter _filter = ChatRoomFilter.all;
  List<ChatRoom> _rooms = [];
  bool isLoading = false;

  /// 목록을 못 가져온 사유. 로그인이 필요하거나 서버가 응답하지 않는 경우다.
  String? errorMessage;

  ChatRoomFilter get filter => _filter;

  List<ChatRoom> get filteredRooms {
    if (_filter == ChatRoomFilter.all) return _rooms;
    final target = _filter == ChatRoomFilter.upcoming
        ? ChatRoomType.upcoming
        : ChatRoomType.past;
    return _rooms.where((r) => r.type == target).toList();
  }

  void setFilter(ChatRoomFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  Future<void> loadRooms() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      _rooms = await _repository.getChatRooms();
    } on ApiException catch (e) {
      // 대화방은 로그인해야 볼 수 있다. 예외를 그대로 던지면 화면이 비어
      // 있는 이유를 알려 줄 수 없다.
      _rooms = const [];
      errorMessage = e.statusCode == 401 ? '로그인하면 대화방을 볼 수 있어요.' : e.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// 저장한 일정으로 대화방을 만든다(이미 있으면 그 방이 온다).
  ///
  /// 반환: 방 식별자. 만들지 못했으면 null 이고 사유가 남는다.
  Future<String?> createRoom(int scheduleId) async {
    final repo = _repository;
    if (repo is! ApiChatRepository) return null;
    try {
      final roomId = await repo.createRoom(scheduleId);
      await loadRooms();
      return roomId;
    } on ApiException catch (e) {
      errorMessage = switch (e.code) {
        'CHAT_003' => '내가 저장한 일정으로만 대화방을 만들 수 있어요.',
        'CHAT_002' => '일정을 찾을 수 없어요.',
        _ => e.message,
      };
      notifyListeners();
      return null;
    }
  }
}
