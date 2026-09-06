import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/config/app_config.dart';
import '../../core/state/auth_store.dart';

/// 서버 확인 전 메시지를 환경·계정·방별로 암호화 저장한다.
class ChatOutboxStore {
  ChatOutboxStore(int roomId)
    : _key =
          'chat.outbox:${AppConfig.instance.storageScope}:'
          '${AuthStore.instance.userId ?? 'guest'}:$roomId';
  final String _key;
  final _storage = const FlutterSecureStorage();
  static final Map<String, Future<void>> _writes = {};
  static final Set<String> _withdrawn = {};

  /// Delete only the withdrawn account's pending drafts. Retired controllers
  /// cannot write the deleted account's data back after this boundary.
  static Future<void> deleteAccount(String scope, int userId) async {
    final prefix = 'chat.outbox:$scope:$userId:';
    _withdrawn.add(prefix);
    await Future.wait(_writes.entries
        .where((entry) => entry.key.startsWith(prefix))
        .map((entry) => entry.value.catchError((Object _) {})));
    const storage = FlutterSecureStorage();
    final keys = (await storage.readAll()).keys.where((key) => key.startsWith(prefix));
    for (final key in keys) {
      await storage.delete(key: key);
      _writes.remove(key);
    }
  }

  Future<List<PendingChatMessage>> load() async {
    await (_writes[_key] ?? Future<void>.value());
    final raw = await _storage.read(key: _key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map(
          (v) =>
              PendingChatMessage.fromJson(Map<String, dynamic>.from(v as Map)),
        )
        .toList();
  }

  Future<void> save(List<PendingChatMessage> messages) {
    if (_withdrawn.any(_key.startsWith)) return Future<void>.value();
    final value = jsonEncode(messages.map((m) => m.toJson()).toList());
    final empty = messages.isEmpty;
    final previous = _writes[_key] ?? Future<void>.value();
    final next = previous.catchError((Object _) {}).then((_) async {
      if (_withdrawn.any(_key.startsWith)) return;
      if (empty) {
        await _storage.delete(key: _key);
      } else {
        await _storage.write(key: _key, value: value);
      }
    });
    _writes[_key] = next;
    return next;
  }
}

class PendingChatMessage {
  const PendingChatMessage(this.text, this.clientMsgId, this.createdAt);
  final String text;
  final String clientMsgId;
  final DateTime createdAt;
  Map<String, dynamic> toJson() => {
    'text': text,
    'client_msg_id': clientMsgId,
    'created_at': createdAt.toIso8601String(),
  };
  factory PendingChatMessage.fromJson(Map<String, dynamic> value) =>
      PendingChatMessage(
        value['text'] as String,
        value['client_msg_id'] as String,
        DateTime.parse(value['created_at'] as String),
      );
}
