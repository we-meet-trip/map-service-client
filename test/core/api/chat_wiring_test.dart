import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/api/chat_realtime_service.dart';
import 'package:map_service_client/data/repositories/api_chat_repository.dart';

void main() {
  group('소켓 주소 파생', () {
    test('https 서버는 wss 로 붙는다', () {
      // iOS 는 평문 소켓을 열어 주지 않는다. 이 파생이 틀리면 안드로이드에서는
      // 되고 아이폰에서만 조용히 안 되는 형태로 드러난다.
      expect(
        ChatRealtimeService.endpointFor('https://api.example.com').toString(),
        'wss://api.example.com/ws/chat',
      );
    });

    test('http 서버는 ws 로 붙고, 경로는 통째로 바뀐다', () {
      expect(
        ChatRealtimeService.endpointFor('http://127.0.0.1:8090/api/v1').toString(),
        'ws://127.0.0.1:8090/ws/chat',
      );
    });
  });

  group('서버 응답을 화면이 쓰는 말로 바꾸기', () {
    Map<String, dynamic> row(int? senderId, {String type = 'TEXT'}) => {
          'seq': 3,
          'sender_id': senderId,
          'type': type,
          'content': '안녕',
          'created_at': '2026-09-10T12:00:00+09:00',
        };

    test('보낸 사람이 나면 내 말로 표시한다', () {
      final message = ApiChatRepository.toMessage(row(7), '1', {7: '지수'}, 7);

      expect(message.isMe, isTrue);
      expect(message.senderName, '지수');
    });

    test('보낸 사람이 남이면 내 말이 아니다', () {
      expect(ApiChatRepository.toMessage(row(8), '1', {8: '현우'}, 7).isMe, isFalse);
    });

    test('로그인 정보가 없으면 어떤 말도 내 말로 세지 않는다', () {
      // 모르는 상태에서 내 말로 세면 남의 말이 오른쪽에 붙어 대화가 뒤집힌다.
      expect(ApiChatRepository.toMessage(row(7), '1', const {}, null).isMe, isFalse);
    });

    test('안내 말은 보낸 사람이 없다', () {
      final message =
          ApiChatRepository.toMessage(row(null, type: 'SYSTEM'), '1', const {}, 7);

      expect(message.isMe, isFalse);
      expect(message.senderName, '안내');
    });

    test('이름을 못 찾으면 번호라도 남긴다', () {
      // 빈 이름으로 두면 누가 말했는지가 화면에서 사라진다.
      expect(ApiChatRepository.toMessage(row(9), '1', const {}, 7).senderName, '9');
    });
  });

  group('실시간 사건 해석', () {
    test('모르는 종류는 버리지 않고 unknown 으로 접는다', () {
      final event = ChatEvent.fromJson({'type': 'BRAND_NEW', 'room_id': 2});

      expect(event.kind, ChatEventKind.unknown);
      expect(event.roomId, 2);
    });
  });
}
