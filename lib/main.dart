import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/naver_map/naver_map_adapter.dart';
import 'core/state/user_repository.dart';
import 'data/local/message_local_store.dart';
import 'data/local/profile_local_store.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Hive.initFlutter();
  await MessageLocalStore.init();
  await ProfileLocalStore.init();
  await UserRepository.init();
  await dotenv.load(fileName: ".env");
  await FlutterNaverMap().init(
    clientId: dotenv.env['NAVER_MAP_CLIENT_ID'] ?? '',
    onAuthFailed: (e) => debugPrint('NaverMap 인증 실패: $e'),
  );
  runApp(const App());
}