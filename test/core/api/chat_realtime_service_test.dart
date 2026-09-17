import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/api/chat_realtime_service.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

void main() {
  group('소켓 주소 파생', () {
    test('안전한 연결이면 wss 로 연다', () {
      final uri = ChatRealtimeService.endpointFor('https://example.invalid');

      expect(uri.scheme, 'wss');
      expect(uri.host, 'example.invalid');
      expect(uri.path, '/ws/chat');
    });

    test('평문 연결이면 ws 로 연다', () {
      final uri = ChatRealtimeService.endpointFor('http://localhost:8080');

      expect(uri.scheme, 'ws');
      expect(uri.port, 8080);
      expect(uri.path, '/ws/chat');
    });

    test('서버 주소에 경로가 붙어 있어도 소켓 경로로 갈아 끼운다', () {
      final uri = ChatRealtimeService.endpointFor('https://example.invalid/api');

      expect(uri.toString(), 'wss://example.invalid/ws/chat');
    });
  });

  group('프레임 해석', () {
    test('본문이 비었거나 깨져 있어도 던지지 않는다', () {
      expect(ChatEvent.parse(null).kind, ChatEventKind.unknown);
      expect(ChatEvent.parse('').kind, ChatEventKind.unknown);
      expect(ChatEvent.parse('{not json').kind, ChatEventKind.unknown);
      expect(ChatEvent.parse('[1,2]').kind, ChatEventKind.unknown);
    });

    test('모르는 종류는 흘려보낸다', () {
      final event = ChatEvent.parse('{"type":"SOMETHING_NEW"}');

      expect(event.kind, ChatEventKind.unknown);
    });

    test('방 방송은 봉투를 벗기고 방 번호를 싣는다', () {
      final event = ChatEvent.parse(
        '{"type":"SYSTEM","room_id":7,"data":{"seq":1,"type":"SYSTEM"}}',
      );

      expect(event.kind, ChatEventKind.system);
      expect(event.roomId, 7);
      expect(event.data?['seq'], 1);
    });

    test('방이 닫히면 본문 없이 종류만 온다', () {
      final event = ChatEvent.parse(
        '{"type":"ROOM_CLOSED","room_id":7,"data":null}',
      );

      expect(event.kind, ChatEventKind.roomClosed);
      expect(event.roomId, 7);
      expect(event.data, isNull);
    });
  });

  test('CONNECT 프레임에 인증 헤더를 실을 수 있다', () {
    // 인증을 핸드셰이크가 아니라 CONNECT 로 하는 구조라, 이 통로가 막히면
    // 채팅이 통째로 붙지 못한다.
    final headers = <String, String>{'Authorization': 'Bearer first'};
    final config = StompConfig(
      url: 'wss://example.invalid/ws/chat',
      stompConnectHeaders: headers,
    );

    expect(config.stompConnectHeaders?['Authorization'], 'Bearer first');

    // 같은 맵의 값만 바꿔도 다음 연결에 새 토큰이 실린다.
    headers['Authorization'] = 'Bearer second';
    expect(config.stompConnectHeaders?['Authorization'], 'Bearer second');
  });

  group('토큰 수명에 맞춘 재접속', () {
    String tokenExpiringAt(DateTime moment) {
      String seg(Map<String, dynamic> value) => base64Url
          .encode(utf8.encode(jsonEncode(value)))
          .replaceAll('=', '');
      final exp = moment.millisecondsSinceEpoch ~/ 1000;
      return '${seg({'alg': 'RS256'})}.${seg({'exp': exp})}.signature';
    }

    test('토큰에 적힌 만료 시각을 읽는다', () {
      final moment = DateTime.utc(2026, 9, 16, 12);

      expect(
        ChatRealtimeService.accessTokenExpiry(tokenExpiringAt(moment)),
        moment,
      );
    });

    test('토큰 모양이 아니면 만료를 모른다고 답한다', () {
      expect(ChatRealtimeService.accessTokenExpiry(null), isNull);
      expect(ChatRealtimeService.accessTokenExpiry('not-a-token'), isNull);
      expect(ChatRealtimeService.accessTokenExpiry('a.b.c'), isNull);
    });

    test('만료를 모르면 미리 붙을 시각도 정하지 않는다', () {
      expect(ChatRealtimeService.renewDelay(null, DateTime.utc(2026)), isNull);
    });

    test('만료 전에 미리 붙도록 앞당겨 예약한다', () {
      final now = DateTime.utc(2026, 9, 16, 12);

      final delay = ChatRealtimeService.renewDelay(
        now.add(const Duration(minutes: 60)),
        now,
      );

      // 수명이 다한 뒤에는 서버가 내보내기를 멈추는데 소켓은 멀쩡해 보인다.
      // 그 자리에 닿기 전에 먼저 붙어야 한다.
      expect(delay, const Duration(minutes: 58));
    });

    test('이미 지난 만료면 곧바로 다시 붙는다', () {
      final now = DateTime.utc(2026, 9, 16, 12);

      expect(
        ChatRealtimeService.renewDelay(now.subtract(const Duration(hours: 1)), now),
        Duration.zero,
      );
    });
  });
}
