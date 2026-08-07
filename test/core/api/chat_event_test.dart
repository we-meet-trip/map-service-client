import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/api/chat_realtime_service.dart';

/// 개인 오류 큐로 오는 ERROR 프레임 해석 검증.
///
/// 오류는 방 방송과 달리 data 로 싸여 오지 않고 code/message/status/
/// destination 이 최상위에 실린다. 이 프레임을 놓치면 거절된 전송이
/// 흔적 없이 사라진다.
void main() {
  test('ERROR 프레임은 error 종류로, 사유와 본문을 함께 싣는다', () {
    final event = ChatEvent.fromJson({
      'type': 'ERROR',
      'code': 'CHAT_011',
      'message': '메시지가 너무 깁니다.',
      'status': 400,
      'destination': '/app/rooms/7/send',
    });

    expect(event.kind, ChatEventKind.error);
    expect(event.reason, '메시지가 너무 깁니다.');
    expect(event.data?['code'], 'CHAT_011');
    expect(event.data?['destination'], '/app/rooms/7/send');
  });

  test('방 방송 프레임 해석은 그대로다', () {
    final event = ChatEvent.fromJson({
      'type': 'MESSAGE',
      'data': {'seq': 3, 'content': '안녕하세요'},
    });

    expect(event.kind, ChatEventKind.message);
    expect(event.data?['content'], '안녕하세요');
  });
}
