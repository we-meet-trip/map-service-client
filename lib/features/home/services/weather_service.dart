import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../common/utils/korea_bounds.dart';
import '../../../core/api/api_client.dart';
import '../models/weather_data.dart';

/// 홈 화면 날씨 카드의 데이터 공급자.
///
/// 기기 위치만 서버에 넘기고, 실황·예보·대기오염을 합친 결과를 받는다.
/// 예전에는 앱이 기상 기관 세 곳을 직접 불러 격자 변환과 발표 시각 계산까지
/// 했는데, 그러려면 인증키를 앱에 넣어야 했고 같은 계산이 서버와 앱 양쪽에
/// 중복으로 존재했다.
class WeatherService {
  /// 화면을 오갈 때마다 다시 부르지 않도록 잠시 들고 있는다. 실황이 매시
  /// 갱신이라 이보다 자주 물어도 대체로 같은 값이 온다.
  static const _cacheDuration = Duration(minutes: 30);

  static WeatherData? _cache;
  static DateTime? _cacheTime;

  /// 담아 둔 값이 대표 지점 기준인지. 정확한 위치로 다시 물을 때는 쓰지 않는다.
  static bool _cacheApproximate = false;

  /// 마지막으로 돌려준 값이 대표 지점 기준인지.
  ///
  /// 위 [_cacheApproximate] 와 다르다 — 그쪽은 담아 둔 값을 다시 써도 되는지를
  /// 가리고, 이쪽은 화면이 '대략적인 위치 기준' 이라고 알릴지를 가린다. 위치를
  /// 거부한 경우뿐 아니라 국내 범위 밖이어서 갈음한 경우에도 참이 된다.
  static bool _resultApproximate = false;
  static bool get resultApproximate => _resultApproximate;

  /// [useApproximateLocation] 이 참이면 기기 위치를 묻지 않고 대표 좌표로
  /// 조회한다. 위치 제공을 미룬 사용자에게 카드를 통째로 비우는 대신
  /// 대표 지점 날씨라도 보여주기 위한 길.
  Future<WeatherData> fetchWeather({
    bool useApproximateLocation = false,
  }) async {
    final now = DateTime.now();
    final cached = _cache;
    final cachedAt = _cacheTime;
    if (cached != null &&
        cachedAt != null &&
        now.difference(cachedAt) < _cacheDuration &&
        (useApproximateLocation || !_cacheApproximate)) {
      return cached;
    }

    final (lat, lng, approximated) = useApproximateLocation
        ? (KoreaBounds.fallbackLat, KoreaBounds.fallbackLng, true)
        : await _resolvePosition();
    // 공통 통로로 보낸다. 직접 보내면 토큰이 실리지 않아, 서버에서 인증을
    // 켜는 순간 홈 화면 첫 진입의 날씨 카드가 곧바로 막힌다.
    final Map<String, dynamic> body;
    try {
      body = await ApiClient.instance.get(
        '/api/v1/weather/home',
        query: {
          'lat': lat.toString(),
          'lng': lng.toString(),
        },
        timeout: const Duration(seconds: 15),
      );
    } on ApiException {
      throw Exception('날씨 정보를 가져오지 못했어요.');
    }
    final data = WeatherData.fromJson(body);

    // 그릴 것이 하나도 없는 응답은 담아 두지 않는다. 담으면 화면의 '다시 시도'
    // 가 캐시 기간 내내 같은 빈 값을 되돌려 받아 버튼이 죽는다.
    if (data.hasAnything) {
      _cache = data;
      _cacheTime = now;
      _cacheApproximate = useApproximateLocation;
    }
    _resultApproximate = approximated;
    return data;
  }

  /// 조회에 쓸 좌표를 정한다.
  ///
  /// 위치를 못 얻거나 국내 범위를 벗어나면 대표 좌표로 갈음한다. 서버가 국내
  /// 밖 좌표를 거절하므로, 해외에서 앱을 열었을 때 카드가 오류로 비는 대신
  /// 서울 날씨라도 보이게 한다.
  /// 세 번째 값은 대표 지점으로 갈음했는지다. 화면이 그 사실을 알린다.
  Future<(double, double, bool)> _resolvePosition() async {
    try {
      final pos = await _location();
      final resolved = KoreaBounds.clampToService(pos.latitude, pos.longitude);
      if (!resolved.$3) return resolved;
      debugPrint('[Weather] 국내 범위 밖 위치 → 기본 좌표 사용');
    } catch (_) {
      debugPrint('[Weather] 위치 확인 실패 → 기본 좌표 사용');
    }
    return (KoreaBounds.fallbackLat, KoreaBounds.fallbackLng, true);
  }

  Future<Position> _location() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('위치 서비스가 비활성화되어 있습니다.');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('위치 권한이 거부되었습니다.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('위치 권한이 영구적으로 거부되었습니다. 설정에서 허용해주세요.');
    }

    if (!kIsWeb) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('위치 정보 요청 시간이 초과됐어요.'),
    );
  }
}
