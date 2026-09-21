/// 서비스가 다루는 좌표 범위와, 그 밖에서 대신 쓰는 대표 지점.
///
/// 발급처가 전부 국내 자료라 범위 밖 좌표로 물으면 서버가 거절한다. 화면마다
/// 같은 숫자를 따로 들고 있으면 한 곳만 고쳐졌을 때 화면끼리 다른 답을 내므로
/// 여기 한 곳에 둔다.
class KoreaBounds {
  const KoreaBounds._();

  static const double minLat = 33;
  static const double maxLat = 43;
  static const double minLng = 124;
  static const double maxLng = 132;

  /// 서울시청. 범위 밖일 때 대신 보여 주는 지점.
  static const double fallbackLat = 37.5665;
  static const double fallbackLng = 126.9780;

  static bool contains(double lat, double lng) =>
      lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;

  /// 범위 안이면 받은 좌표를, 밖이면 대표 지점을 준다.
  ///
  /// 세 번째 값은 갈음했는지다 — 화면이 그 사실을 알려야 하기 때문이다.
  /// 조용히 바꿔 놓으면 서울 자료를 자기 주변 자료로 읽게 된다.
  static (double, double, bool) clampToService(double lat, double lng) =>
      contains(lat, lng)
          ? (lat, lng, false)
          : (fallbackLat, fallbackLng, true);
}
