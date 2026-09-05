import 'package:url_launcher/url_launcher.dart';

/// 문의·신고 메일의 수신 주소. 한 곳에서만 바꾸면 전 화면에 적용된다.
const String supportEmail = 'mapadmin26@gmail.com';

/// 기본 메일 앱을 문의 양식으로 연다. 열 수 있으면 true.
///
/// 쿼리는 직접 인코딩해 조립한다 — Uri(queryParameters:)는 공백을 +로
/// 바꾸는데, 메일 앱은 그 +를 문자 그대로 보여 준다.
Future<bool> launchSupportMail({
  required String subject,
  String body = '',
}) async {
  final query = 'subject=${Uri.encodeComponent(subject)}'
      '${body.isEmpty ? '' : '&body=${Uri.encodeComponent(body)}'}';
  final uri = Uri.parse('mailto:$supportEmail?$query');
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Exception {
    return false;
  }
}
