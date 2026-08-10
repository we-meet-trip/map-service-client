import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/api/api_client.dart';
import 'package:map_service_client/core/api/chat_api_service.dart';
import 'package:map_service_client/core/api/invite_api_service.dart';
import 'package:map_service_client/data/repositories/api_invite_repository.dart';

/// 미리보기와 참가 두 호출을 흉내 낸다. 실제 통신은 이 파일의 관심이 아니다.
class _FakeInviteApi implements InviteApiService {
  _FakeInviteApi({this.previewResult, this.previewError, this.joinResult, this.joinError});

  final InvitePreviewResponse? previewResult;
  final ApiException? previewError;
  final ChatRoomResponse? joinResult;
  final ApiException? joinError;

  int previewCalls = 0;
  int joinCalls = 0;

  @override
  Future<InvitePreviewResponse> preview(String token) async {
    previewCalls++;
    if (previewError != null) throw previewError!;
    return previewResult!;
  }

  @override
  Future<ChatRoomResponse> join(String token) async {
    joinCalls++;
    if (joinError != null) throw joinError!;
    return joinResult!;
  }

  @override
  Future<InviteLinkResponse> generate(int roomId) => throw UnimplementedError();

  @override
  Future<void> revoke(int roomId) => throw UnimplementedError();
}

InvitePreviewResponse _preview({bool joinable = true}) => InvitePreviewResponse(
      roomId: 7,
      title: '속초 당일치기',
      participantCount: 2,
      joinable: joinable,
      expiresAt: DateTime.now().add(const Duration(days: 5)),
    );

void main() {
  test('처음 참가하면 서버가 준 방을 그대로 돌려준다', () async {
    final api = _FakeInviteApi(
      joinResult: ChatRoomResponse(
        roomId: 7,
        scheduleId: 11,
        ownerId: 1,
        title: '속초 당일치기',
        readOnly: false,
        expiresAt: DateTime.now().add(const Duration(days: 5)),
        participantCount: 3,
        latestSeq: 4,
      ),
    );

    final result = await ApiInviteRepository(api: api).join('tok');

    expect(result.success, isTrue);
    expect(result.alreadyJoined, isFalse);
    expect(result.chatRoomId, 7);
    expect(result.roomTitle, '속초 당일치기');
  });

  test('모르는 토큰의 미리보기는 방 번호 없이 사유만 남는다', () async {
    final api = _FakeInviteApi(
      previewError: const ApiException(
        statusCode: 404,
        code: 'CHAT_008',
        message: '유효하지 않은 초대 링크입니다.',
      ),
    );

    final result = await ApiInviteRepository(api: api).preview('nope');

    expect(result.success, isFalse);
    expect(result.chatRoomId, isNull);
    expect(result.errorMessage, contains('유효하지 않은'));
  });

  test('이미 참가한 사용자는 오류가 아니라 미리보기에서 본 방으로 이어진다', () async {
    // 서버의 409 응답에는 방 번호가 없다. 미리 확인해 둔 번호가 유일한 단서다.
    final api = _FakeInviteApi(
      previewResult: _preview(),
      joinError: const ApiException(
        statusCode: 409,
        code: 'CHAT_007',
        message: '이미 참가한 채팅방입니다.',
      ),
    );
    final repository = ApiInviteRepository(api: api);

    await repository.preview('tok');
    final result = await repository.join('tok');

    expect(result.success, isTrue);
    expect(result.alreadyJoined, isTrue);
    expect(result.chatRoomId, 7);
  });

  test('미리보기를 거치지 않았다면 이미 참가도 방을 특정하지 못해 실패로 남는다', () async {
    final api = _FakeInviteApi(
      joinError: const ApiException(
        statusCode: 409,
        code: 'CHAT_007',
        message: '이미 참가한 채팅방입니다.',
      ),
    );
    final repository = ApiInviteRepository(api: api);

    final result = await repository.join('tok');

    expect(result.success, isFalse);
    expect(result.chatRoomId, isNull);
  });

  test('로그인이 필요한 상태는 오류가 아니라 순서로 구분한다', () async {
    final api = _FakeInviteApi(
      joinError: const ApiException(
        statusCode: 401,
        code: 'UNKNOWN_ERROR',
        message: '로그인이 필요해요.',
      ),
    );
    final repository = ApiInviteRepository(api: api);

    final result = await repository.join('tok');

    expect(result.loginRequired, isTrue);
    expect(result.errorMessage, isNull);
  });

  test('만료된 링크의 미리보기는 방 정보를 싣고 참가 불가만 알린다', () async {
    final api = _FakeInviteApi(previewResult: _preview(joinable: false));
    final repository = ApiInviteRepository(api: api);

    final result = await repository.preview('tok');

    expect(result.success, isFalse);
    expect(result.chatRoomId, 7);
    expect(result.roomTitle, '속초 당일치기');
  });

  group('오류 코드별 안내', () {
    Future<String?> messageFor(String code) async {
      final api = _FakeInviteApi(
        joinError: ApiException(statusCode: 400, code: code, message: '서버 문구'),
      );
      final result = await ApiInviteRepository(api: api).join('tok');
      return result.errorMessage;
    }

    test('무엇 때문에 못 들어가는지 코드마다 다르게 알린다', () async {
      // 전부 한 문구로 뭉치면 다음에 뭘 해야 할지 알 수 없어진다.
      final invalid = await messageFor('CHAT_008');
      final revoked = await messageFor('CHAT_009');
      final full = await messageFor('CHAT_006');
      final kicked = await messageFor('CHAT_010');

      expect(invalid, contains('유효하지 않은'));
      expect(revoked, contains('만료'));
      expect(full, contains('정원'));
      expect(kicked, contains('다시 참가할 수 없'));
      expect({invalid, revoked, full, kicked}, hasLength(4));
    });
  });
}
