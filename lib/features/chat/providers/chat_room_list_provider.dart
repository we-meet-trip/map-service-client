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
    notifyListeners();
    try {
      _rooms = await _repository.getChatRooms();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
