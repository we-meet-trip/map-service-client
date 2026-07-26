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
    notifyListeners();
    try {
      _rooms = await _repository.getChatRooms();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
