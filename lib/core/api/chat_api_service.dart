import '../state/auth_store.dart';
import 'api_client.dart';

/// 채팅 REST 호출.
///
/// 실시간 소켓과 역할이 갈린다. 소켓은 "지금 오는 말"만 나르고, 목록·기록·
/// 참가자처럼 화면을 처음 그릴 때 필요한 것은 전부 이쪽으로 받는다. 소켓이
/// 끊겼다 붙어도 브로커는 지나간 말을 다시 주지 않으므로, 다시 붙은 뒤에는
/// 기록을 이 경로로 한 번 더 읽어야 빈 구간이 생기지 않는다.
class ChatApiService {
  ChatApiService._();
  static final ChatApiService instance = ChatApiService._();

  static const _base = '/api/v1/chat';

  /// 내가 속한 방 목록.
  Future<List<Map<String, dynamic>>> listRooms() async {
    final rows = await ApiClient.instance.getList('$_base/rooms');
    return rows.cast<Map<String, dynamic>>();
  }

  /// 일정에 붙은 방을 만든다. 같은 일정으로 다시 불러도 같은 방이 온다.
  Future<Map<String, dynamic>> createRoom(int scheduleId) =>
      ApiClient.instance.post('$_base/rooms', body: {'schedule_id': scheduleId});

  /// 일정으로 방을 찾는다. 없으면 예외가 올라온다.
  Future<Map<String, dynamic>> roomBySchedule(int scheduleId) =>
      ApiClient.instance.get('$_base/rooms/by-schedule/$scheduleId');

  /// 방의 지난 말들. beforeSeq 를 주면 그보다 앞의 것을 준다(위로 넘기기).
  Future<Map<String, dynamic>> history(int roomId, {int? beforeSeq, int? limit}) =>
      ApiClient.instance.get('$_base/rooms/$roomId/messages', query: {
        if (beforeSeq != null) 'before_seq': '$beforeSeq',
        if (limit != null) 'limit': '$limit',
      });

  /// 참가자 목록. 보낸 사람 번호를 이름으로 바꾸는 데 쓴다 —
  /// 실시간 이벤트에는 번호만 실려 온다.
  Future<List<Map<String, dynamic>>> participants(int roomId) async {
    final rows = await ApiClient.instance.getList('$_base/rooms/$roomId/participants');
    return rows.cast<Map<String, dynamic>>();
  }

  /// 소켓이 끊겼을 때 쓰는 전송 경로. 소켓 전송과 같은 결과를 남긴다.
  Future<Map<String, dynamic>> send(int roomId, String content, String clientMsgId) =>
      ApiClient.instance.post('$_base/rooms/$roomId/messages',
          body: {'content': content, 'client_msg_id': clientMsgId});

  /// 여기까지 읽었다고 알린다.
  Future<Map<String, dynamic>> markRead(int roomId, int lastReadSeq) =>
      ApiClient.instance.post('$_base/rooms/$roomId/read',
          body: {'last_read_seq': lastReadSeq});

  /// 초대 링크를 발급한다.
  Future<Map<String, dynamic>> createInvite(int roomId) =>
      ApiClient.instance.post('$_base/rooms/$roomId/invite');

  /// 초대 링크로 방에 들어간다.
  Future<Map<String, dynamic>> join(String token) =>
      ApiClient.instance.post('$_base/invites/$token/join');

  /// 로그인한 사람의 번호. 내 말과 남의 말을 가르는 데 쓴다.
  int? get myUserId => AuthStore.instance.userId;
}
