import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/api/chat_api_service.dart';
import 'package:map_service_client/core/api/invite_api_service.dart';

/// 서버에 전역 이름 규칙이 없어 필드마다 표기를 따로 붙이는 구조다. 하나를
/// 잘못 읽어도 컴파일은 통과하고 화면에서만 값이 비어 보이므로, 키를 직접 건다.
void main() {
  group('ChatRoomSummary', () {
    test('스네이크 케이스 키를 그대로 읽는다', () {
      final summary = ChatRoomSummary.fromJson({
        'room_id': 3,
        'schedule_id': 11,
        'title': '속초 당일치기',
        'read_only': false,
        'unread_count': 4,
        'last_message': '내일 봐요',
        'last_message_at': '2026-08-10T09:00:00+09:00',
        'latest_seq': 12,
        'participant_count': 3,
      });

      expect(summary.roomId, 3);
      expect(summary.scheduleId, 11);
      expect(summary.unreadCount, 4);
      expect(summary.lastMessage, '내일 봐요');
      expect(summary.lastMessageAt, isNotNull);
      expect(summary.latestSeq, 12);
      expect(summary.participantCount, 3);
    });

    test('아직 아무도 말하지 않은 방은 마지막 대화가 비어 있다', () {
      final summary = ChatRoomSummary.fromJson({
        'room_id': 3,
        'schedule_id': 11,
        'title': '속초 당일치기',
        'read_only': false,
        'unread_count': 0,
        'last_message': null,
        'last_message_at': null,
        'latest_seq': 0,
        'participant_count': 1,
      });

      expect(summary.lastMessage, isNull);
      expect(summary.lastMessageAt, isNull);
    });

    test('인원수가 빠진 응답에서도 최소 1로 읽어 화면이 비지 않는다', () {
      final summary = ChatRoomSummary.fromJson({
        'room_id': 3,
        'schedule_id': 11,
        'title': '속초 당일치기',
        'read_only': false,
        'unread_count': 0,
        'latest_seq': 0,
      });

      expect(summary.participantCount, 1);
    });
  });

  group('ChatMessageResponse', () {
    test('시스템 메시지는 보낸 사람이 없고 구조화 정보를 싣는다', () {
      final message = ChatMessageResponse.fromJson({
        'room_id': 3,
        'seq': 1,
        'sender_id': null,
        'type': 'SYSTEM',
        'content': '여행 일정을 확인해보세요.',
        'system_payload': {'kind': 'VIEW_ITINERARY', 'schedule_id': 11},
        'created_at': '2026-08-10T09:00:00+09:00',
        'unread_count': 0,
      });

      expect(message.senderId, isNull);
      expect(message.type, 'SYSTEM');
      expect(message.systemPayload?['kind'], 'VIEW_ITINERARY');
      expect(message.systemPayload?['schedule_id'], 11);
      expect(message.clientMsgId, isNull);
    });

    test('방금 보낸 메시지는 임시 식별자를 되받는다', () {
      final message = ChatMessageResponse.fromJson({
        'room_id': 3,
        'seq': 5,
        'sender_id': 7,
        'type': 'TEXT',
        'content': '안녕하세요',
        'system_payload': null,
        'created_at': '2026-08-10T09:00:00+09:00',
        'unread_count': 2,
        'client_msg_id': 'c-42',
      });

      expect(message.senderId, 7);
      expect(message.clientMsgId, 'c-42');
      expect(message.unreadCount, 2);
    });
  });

  group('ChatHistoryResponse', () {
    test('더 읽을 것이 없으면 커서가 비어 있다', () {
      final history = ChatHistoryResponse.fromJson({
        'messages': [
          {'room_id': 3, 'seq': 2, 'type': 'TEXT', 'content': 'b'},
          {'room_id': 3, 'seq': 1, 'type': 'TEXT', 'content': 'a'},
        ],
        'next_cursor': null,
      });

      expect(history.messages, hasLength(2));
      expect(history.messages.first.seq, 2);
      expect(history.nextCursor, isNull);
    });
  });

  group('초대', () {
    test('발급 응답은 서버가 만든 주소를 그대로 준다', () {
      final invite = InviteLinkResponse.fromJson({
        'token': 'tok',
        'url': 'https://mapcenter-b59ca.web.app/invite/tok',
        'version': 2,
        'expires_at': '2026-08-17T23:59:59+09:00',
      });

      expect(invite.token, 'tok');
      expect(invite.url, 'https://mapcenter-b59ca.web.app/invite/tok');
      expect(invite.version, 2);
      expect(invite.expiresAt, isNotNull);
    });

    test('만료된 링크의 미리보기도 방 정보를 싣고 joinable 만 거짓이다', () {
      final preview = InvitePreviewResponse.fromJson({
        'room_id': 3,
        'title': '속초 당일치기',
        'participant_count': 2,
        'joinable': false,
        'expires_at': '2026-08-01T23:59:59+09:00',
      });

      expect(preview.roomId, 3);
      expect(preview.title, '속초 당일치기');
      expect(preview.joinable, isFalse);
    });
  });
}
