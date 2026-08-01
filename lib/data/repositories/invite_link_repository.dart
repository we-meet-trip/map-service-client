import 'dart:math';

abstract class InviteLinkRepository {
  Future<String> generateInviteLink(String roomId, String roomTitle);
}

class MockInviteLinkRepository implements InviteLinkRepository {
  static final _random = Random();

  @override
  Future<String> generateInviteLink(String roomId, String roomTitle) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final slug = roomTitle.trim().replaceAll(' ', '-').toLowerCase();
    final token = List.generate(6, (_) {
      const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
      return chars[_random.nextInt(chars.length)];
    }).join();
    return 'map-app/invite-$slug-$token';
  }
}
