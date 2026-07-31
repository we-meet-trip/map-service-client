import 'package:hive_flutter/hive_flutter.dart';
import '../models/chat_message.dart';

class MessageLocalStore {
  MessageLocalStore._();
  static final MessageLocalStore instance = MessageLocalStore._();

  static const _boxName = 'chat_messages';
  static Box? _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  Box get _b => _box!;

  List<ChatMessage> getMessages(String roomId) {
    return _b.values
        .whereType<Map>()
        .where((m) => m['roomId'] == roomId)
        .map((m) => _fromMap(Map<String, dynamic>.from(m)))
        .toList()
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
  }

  bool hasMessages(String roomId) =>
      _b.values.whereType<Map>().any((m) => m['roomId'] == roomId);

  Future<void> saveMessage(ChatMessage msg) => _b.put(msg.id, _toMap(msg));

  Future<void> saveMessages(List<ChatMessage> msgs) =>
      _b.putAll({for (final m in msgs) m.id: _toMap(m)});

  Map<String, dynamic> _toMap(ChatMessage m) => {
        'id': m.id,
        'roomId': m.roomId,
        'senderId': m.senderId,
        'senderName': m.senderName,
        'senderAvatarUrl': m.senderAvatarUrl,
        'text': m.text,
        'sentAt': m.sentAt.millisecondsSinceEpoch,
        'isMe': m.isMe,
      };

  ChatMessage _fromMap(Map<String, dynamic> m) => ChatMessage(
        id: m['id'] as String,
        roomId: m['roomId'] as String,
        senderId: m['senderId'] as String,
        senderName: m['senderName'] as String,
        senderAvatarUrl: m['senderAvatarUrl'] as String?,
        text: m['text'] as String,
        sentAt: DateTime.fromMillisecondsSinceEpoch(m['sentAt'] as int),
        isMe: m['isMe'] as bool,
      );
}
