import 'dart:math';

import 'api_client.dart';

enum ReportContentType { chatMessage, trip, vision }

extension ReportContentTypeLabel on ReportContentType {
  String get apiValue => switch (this) {
    ReportContentType.chatMessage => 'CHAT_MESSAGE',
    ReportContentType.trip => 'TRIP',
    ReportContentType.vision => 'VISION',
  };
  String get label => switch (this) {
    ReportContentType.chatMessage => '채팅 메시지',
    ReportContentType.trip => '생성 일정',
    ReportContentType.vision => 'Vision 답변',
  };
}

enum ReportReason {
  harassment('HARASSMENT', '괴롭힘·욕설'),
  hate('HATE', '혐오·차별'),
  sexualContent('SEXUAL_CONTENT', '성적 콘텐츠'),
  violence('VIOLENCE', '폭력'),
  dangerousOrIllegal('DANGEROUS_OR_ILLEGAL', '위험하거나 불법인 내용'),
  spam('SPAM', '스팸·광고'),
  privacy('PRIVACY', '개인정보 침해'),
  inaccurate('INACCURATE', '잘못된 정보'),
  other('OTHER', '기타');

  const ReportReason(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

/// Only references understood by the server; images and message bodies are never attached.
class ReportTarget {
  const ReportTarget.chat({required this.roomId, required this.messageSeq})
    : type = ReportContentType.chatMessage,
      scheduleId = null,
      recommendJobId = null;
  const ReportTarget.trip({this.scheduleId, this.recommendJobId})
    : type = ReportContentType.trip,
      roomId = null,
      messageSeq = null;
  const ReportTarget.vision()
    : type = ReportContentType.vision,
      roomId = null,
      messageSeq = null,
      scheduleId = null,
      recommendJobId = null;

  final ReportContentType type;
  final int? roomId;
  final int? messageSeq;
  final int? scheduleId;
  final String? recommendJobId;
  bool get valid => switch (type) {
    ReportContentType.chatMessage => (roomId ?? 0) > 0 && (messageSeq ?? 0) > 0,
    ReportContentType.trip =>
      scheduleId != null
          ? scheduleId! > 0 && recommendJobId == null
          : recommendJobId != null && _uuid.hasMatch(recommendJobId!),
    ReportContentType.vision => true,
  };

  Map<String, Object> toJson() {
    if (!valid) throw const FormatException('Invalid report reference');
    return {
      'content_type': type.apiValue,
      'room_id': ?roomId,
      'message_seq': ?messageSeq,
      'schedule_id': ?scheduleId,
      'recommend_job_id': ?recommendJobId,
    };
  }
}

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

String newReportRequestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Immutable payload retained through a timeout/retry, including its UUID.
class ReportSubmission {
  ReportSubmission({
    required this.target,
    required this.reason,
    required this.clientRequestId,
    String? description,
  }) : description = description?.trim();
  final ReportTarget target;
  final ReportReason reason;
  final String clientRequestId;
  final String? description;
  Map<String, Object> toJson() {
    if (!_uuid.hasMatch(clientRequestId) ||
        (description?.length ?? 0) > 1000 ||
        (target.type == ReportContentType.vision &&
            (description?.isEmpty ?? true))) {
      throw const FormatException('Invalid report submission');
    }
    return {
      ...target.toJson(),
      'client_request_id': clientRequestId,
      'reason': reason.apiValue,
      if (description?.isNotEmpty ?? false) 'description': description!,
    };
  }
}

class ModerationReport {
  const ModerationReport({
    required this.reportId,
    required this.status,
    required this.createdAt,
    this.contentType,
    this.reason,
    this.resolution,
  });
  final String reportId;
  final String status;
  final DateTime createdAt;
  final String? contentType;
  final String? reason;
  final String? resolution;
  String? get resolutionLabel => switch (resolution) {
    'REVIEW' => '운영자가 내용을 검토하고 있어요.',
    'DISMISS' => '검토가 종료됐어요.',
    'HIDE_CHAT_MESSAGE' => '대상 메시지가 숨겨졌어요.',
    'RESTRICT_CHAT' => '대상 계정의 채팅이 제한됐어요.',
    'RESOLVE' => '처리가 완료됐어요.',
    _ => null,
  };
  String get statusLabel => switch (status) {
    'OPEN' => '접수됨',
    'IN_REVIEW' => '검토 중',
    'ACTIONED' => '조치 완료',
    'DISMISSED' => '검토 완료',
    _ => '상태 확인 필요',
  };
  factory ModerationReport.fromJson(Map<String, dynamic> json) {
    final id = json['report_id'];
    final created = DateTime.tryParse(json['created_at']?.toString() ?? '');
    final status = json['status'];
    if (id is! String ||
        !_uuid.hasMatch(id) ||
        created == null ||
        !const {
          'OPEN',
          'IN_REVIEW',
          'ACTIONED',
          'DISMISSED',
        }.contains(status)) {
      throw const FormatException('Invalid report response');
    }
    return ModerationReport(
      reportId: id,
      status: status as String,
      createdAt: created,
      contentType: json['content_type'] as String?,
      reason: json['reason'] as String?,
      resolution: json['resolution'] as String?,
    );
  }
}

class BlockedUser {
  const BlockedUser({required this.userId, this.nickname});
  final int userId;
  final String? nickname;
  String get label =>
      nickname?.trim().isNotEmpty == true ? nickname! : '차단한 사용자';
  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    final id = json['blocked_user_id'];
    if (id is! int || id <= 0) {
      throw const FormatException('Invalid blocked user');
    }
    return BlockedUser(userId: id, nickname: json['nickname'] as String?);
  }
}

class ModerationApiService {
  ModerationApiService({ApiClient? api}) : _api = api ?? ApiClient.instance;
  final ApiClient _api;
  static final instance = ModerationApiService();
  static const _base = '/api/v1/moderation';

  Future<ModerationReport> report(ReportSubmission submission) async =>
      ModerationReport.fromJson(
        await _api.post('$_base/reports', body: submission.toJson()),
      );
  Future<List<ModerationReport>> reports() async =>
      (await _list('$_base/reports')).map(ModerationReport.fromJson).toList();
  Future<List<BlockedUser>> blocks() async =>
      (await _list('$_base/blocks')).map(BlockedUser.fromJson).toList();
  Future<List<Map<String, dynamic>>> _list(String path) async {
    final response = await _api.get(path);
    final data = response['data'];
    if (data is! List || data.any((item) => item is! Map<String, dynamic>)) {
      throw const FormatException('Invalid moderation list');
    }
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> block(int userId) async {
    if (userId <= 0) throw const FormatException('Invalid user reference');
    await _api.put('$_base/blocks/$userId');
  }

  Future<void> unblock(int userId) async {
    if (userId <= 0) throw const FormatException('Invalid user reference');
    await _api.delete('$_base/blocks/$userId');
  }
}
