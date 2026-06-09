import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'app.dart';

void main()  async{
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterNaverMap().init(
     clientId: const String.fromEnvironment('NAVER_MAP_CLIENT_ID'),
     onAuthFailed: (e) => debugPrint('NaverMap 인증 실패: $e'),
   );
  runApp(const App());
}
