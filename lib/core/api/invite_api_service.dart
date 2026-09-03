import 'api_client.dart';
import 'chat_api_service.dart';

/// 소유자가 발급받은 초대 링크.
class InviteLinkResponse {
  /// 원시 토큰. 서버는 해시만 보관하므로 이 값은 발급 응답에서 한 번만 보인다.
  final String token;

  /// 그대로 공유하면 되는 완성된 주소. 클라이언트가 다시 조립하지 않는다.
  final String url;

  /// 발급 차수. 다시 발급하면 올라가고 이전 링크는 죽는다.
  final int version;

  /// 이 링크가 실제로 언제까지 쓸모 있는지. 링크 만료와 방 만료 중 이른 쪽이다.
  final DateTime? expiresAt;

  const InviteLinkResponse({
    required this.token,
    required this.url,
    required this.version,
    required this.expiresAt,
  });

  factory InviteLinkResponse.fromJson(Map<String, dynamic> json) =>
      InviteLinkResponse(
        token: json['token'] as String? ?? '',
        url: json['url'] as String? ?? '',
        version: (json['version'] as num?)?.toInt() ?? 0,
        expiresAt: json['expires_at'] is String
            ? DateTime.tryParse(json['expires_at'] as String)?.toLocal()
            : null,
      );
}

/// 링크를 받은 사람이 참가 전에 보는 방 정보.
class InvitePreviewResponse {
  final int roomId;
  final String title;
  final int participantCount;

  /// 지금 이 링크로 들어갈 수 있는지. 폐기·만료·정원 초과면 거짓이다.
  final bool joinable;

  final DateTime? expiresAt;

  const InvitePreviewResponse({
    required this.roomId,
    required this.title,
    required this.participantCount,
    required this.joinable,
    required this.expiresAt,
  });

  factory InvitePreviewResponse.fromJson(Map<String, dynamic> json) =>
      InvitePreviewResponse(
        roomId: (json['room_id'] as num?)?.toInt() ?? 0,
        title: json['title'] as String? ?? '',
        participantCount: (json['participant_count'] as num?)?.toInt() ?? 0,
        joinable: json['joinable'] as bool? ?? false,
        expiresAt: json['expires_at'] is String
            ? DateTime.tryParse(json['expires_at'] as String)?.toLocal()
            : null,
      );
}

/// 초대 링크 REST 호출 모음.
class InviteApiService {
  InviteApiService._();
  static final InviteApiService instance = InviteApiService._();

  final _api = ApiClient.instance;

  static const _base = '/api/v1/chat';

  /// 초대 링크를 발급한다(소유자 전용).
  ///
  /// 부를 때마다 새 링크가 나오고 **이전 링크는 즉시 죽는다.** 화면을 열 때마다
  /// 무심코 부르면 방금 친구에게 보낸 주소를 매번 끊게 되므로, 부르는 쪽이
  /// 결과를 들고 있어야 한다.
  Future<InviteLinkResponse> generate(int roomId) async {
    final json = await _api.post('$_base/rooms/$roomId/invite');
    return InviteLinkResponse.fromJson(json);
  }

  /// 발급한 링크를 폐기한다(소유자 전용).
  Future<void> revoke(int roomId) => _api.delete('$_base/rooms/$roomId/invite');

  /// 링크가 가리키는 방을 확인한다. 참가는 일어나지 않는다.
  ///
  /// 로그인하지 않아도 부를 수 있다. 토큰이 없으면 공통 계층이 인증 헤더를
  /// 붙이지 않으므로 따로 할 일은 없다.
  Future<InvitePreviewResponse> preview(String token) async {
    final json = await _api.get('$_base/invites/$token');
    return InvitePreviewResponse.fromJson(json);
  }

  /// 링크로 방에 들어간다. 로그인이 필요하다.
  ///
  /// 이미 들어가 있는 사람에게는 서버가 409 를 준다. 부르는 쪽은 그것을 실패가
  /// 아니라 "이미 들어가 있음"으로 다뤄야 한다.
  Future<ChatRoomResponse> join(String token) async {
    final json = await _api.post('$_base/invites/$token/join');
    return ChatRoomResponse.fromJson(json);
  }
}
