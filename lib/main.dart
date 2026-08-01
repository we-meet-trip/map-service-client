import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/api/auth_api_service.dart';
import 'core/naver_map/naver_map_adapter.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  // 저장해 둔 토큰을 되살리고, 만료됐을 때 갱신할 방법을 꽂아 둔다. 화면이
  // 그려지기 전에 끝내야 첫 화면이 로그인 여부를 제대로 보고 그린다.
  await AuthApiService.instance.bootstrap();
  await FlutterNaverMap().init(
    clientId: dotenv.env['NAVER_MAP_CLIENT_ID'] ?? '',
    onAuthFailed: (e) => debugPrint('NaverMap 인증 실패: $e'),
  );
  runApp(const App());
}