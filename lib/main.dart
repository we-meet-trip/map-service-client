import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/api/auth_api_service.dart';
import 'core/api/service_consent_api_service.dart';
import 'core/api/ai_consent_api_service.dart';
import 'common/widgets/external_ai_consent.dart';
import 'core/state/service_consent_store.dart';
import 'core/config/app_config.dart';
import 'data/local/permission_notice_store.dart';
import 'data/local/profile_local_store.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await PermissionNoticeStore.init();
  await ProfileLocalStore.init();
  // 서버 주소를 먼저 확정한다. 아래 토큰 되살리기가 갱신 요청을 보낼 수
  // 있는데, 그때 주소가 정해져 있지 않으면 엉뚱한 곳으로 나간다.
  await AppConfig.instance.init();
  ServiceConsentApiService.instance.bind(ServiceConsentStore.instance);
  AiConsentApiService.instance.bind(ExternalAiConsentGate.instance);
  // 저장해 둔 토큰을 되살리고, 만료됐을 때 갱신할 방법을 꽂아 둔다. 화면이
  // 그려지기 전에 끝내야 첫 화면이 로그인 여부를 제대로 보고 그린다.
  await AuthApiService.instance.bootstrap();
  // 외부 지도 SDK 로딩도 서버의 이용 조건 확인 뒤에 시작한다.
  runApp(const App());
}
