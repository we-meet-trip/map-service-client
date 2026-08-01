import 'package:flutter/foundation.dart';

import '../../../core/state/auth_store.dart';

/// 로그인 여부를 화면에 알리는 창구.
///
/// **판단은 여기서 하지 않는다.** 토큰 보관소가 유일한 출처이고, 이 클래스는
/// 그 값이 바뀔 때 화면에 알리기만 한다. 자체 상태를 따로 들면 로그인·가입·
/// 앱 시작 복원 중 한 곳만 빠뜨려도 로그인한 사용자가 로그인 화면으로 튕기고,
/// 그런 어긋남은 두 상태가 각각 맞아 보여서 눈에 잘 띄지 않는다.
class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    AuthStore.instance.isLoggedIn.addListener(notifyListeners);
  }

  bool get isLoggedIn => AuthStore.instance.isLoggedIn.value;

  @override
  void dispose() {
    AuthStore.instance.isLoggedIn.removeListener(notifyListeners);
    super.dispose();
  }
}
