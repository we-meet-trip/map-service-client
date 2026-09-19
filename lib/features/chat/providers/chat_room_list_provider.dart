import 'package:flutter/foundation.dart';
import '../../../data/models/chat_room.dart';
import '../../../data/repositories/chat_repository.dart';
import '../models/chat_room.dart';

class ChatRoomListProvider extends ChangeNotifier {
  ChatRoomListProvider(this._repository);

  final ChatRepository _repository;

  ChatRoomFilter _filter = ChatRoomFilter.all;
  List<ChatRoom> _rooms = [];
  bool isLoading = false;

  /// 불러오기에 실패했는지. 빈 목록과 실패를 화면에서 구분하려면 필요하다.
  bool loadFailed = false;

  ChatRoomFilter get filter => _filter;

  List<ChatRoom> get filteredRooms {
    final source = _filter == ChatRoomFilter.all
        ? _rooms
        : _rooms.where((r) {
            final target = _filter == ChatRoomFilter.upcoming
                ? ChatRoomType.upcoming
                : ChatRoomType.past;
            return r.type == target;
          }).toList();

    return [...source]..sort((a, b) {
        if (a.type != b.type) {
          return a.type == ChatRoomType.upcoming ? -1 : 1;
        }
        return b.sortedAt.compareTo(a.sortedAt);
      });
  }

  void setFilter(ChatRoomFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  Future<void> loadRooms() async {
    isLoading = true;
    loadFailed = false;
    notifyListeners();
    try {
      _rooms = await _repository.getChatRooms();
    } catch (_) {
      // 삼키면 '방이 없어요' 와 구분되지 않는다. 화면이 다시 시도를 권할 수
      // 있도록 실패했다는 사실만 남긴다.
      loadFailed = true;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
