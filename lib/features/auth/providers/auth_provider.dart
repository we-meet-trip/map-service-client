import 'package:flutter/foundation.dart';

class AuthProvider extends ChangeNotifier {
  // TODO: 실제 Kakao/Email 로그인 완료 시 setLoggedIn(true) 호출
  bool isLoggedIn = false;

  void setLoggedIn(bool value) {
    isLoggedIn = value;
    notifyListeners();
  }
}
