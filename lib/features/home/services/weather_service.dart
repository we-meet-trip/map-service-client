import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../models/weather_data.dart';

/// 홈 화면 날씨 카드의 데이터 공급자.
///
/// 기기 위치만 서버에 넘기고, 실황·예보·대기오염을 합친 결과를 받는다.
/// 예전에는 앱이 기상 기관 세 곳을 직접 불러 격자 변환과 발표 시각 계산까지
/// 했는데, 그러려면 인증키를 앱에 넣어야 했고 같은 계산이 서버와 앱 양쪽에
/// 중복으로 존재했다.
class WeatherService {
  /// 서버 주소는 시작할 때 정해진다. 상수로 잡아 두면 그 시점의 값이
  /// 굳어져, 원격에서 받은 주소가 반영되지 않는다.
  static String get _baseUrl => kApiBaseUrl;

  /// 화면을 오갈 때마다 다시 부르지 않도록 잠시 들고 있는다. 실황이 매시
  /// 갱신이라 이보다 자주 물어도 대체로 같은 값이 온다.
  static const _cacheDuration = Duration(minutes: 30);

  /// 위치를 못 얻었을 때 대신 쓰는 좌표(서울 시청). 카드가 통째로 비는 것보다
  /// 대표 지점이라도 보여 주는 편이 낫다.
  static const _fallbackLat = 37.5665;
  static const _fallbackLng = 126.9780;

  static WeatherData? _cache;
  static DateTime? _cacheTime;

  /// 담아 둔 값이 대표 지점 기준인지. 정확한 위치로 다시 물을 때는 쓰지 않는다.
  static bool _cacheApproximate = false;

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

    final position = useApproximateLocation
        ? (_fallbackLat, _fallbackLng)
        : await _resolvePosition();
    final uri = Uri.parse('$_baseUrl/api/v1/weather/home').replace(
      queryParameters: {
        'lat': position.$1.toString(),
        'lng': position.$2.toString(),
      },
    );

    final response =
        await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('날씨 정보를 가져오지 못했어요.');
    }
    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final data = WeatherData.fromJson(body);

    _cache = data;
    _cacheTime = now;
    _cacheApproximate = useApproximateLocation;
    return data;
  }

  /// 조회에 쓸 좌표를 정한다.
  ///
  /// 위치를 못 얻거나 국내 범위를 벗어나면 대표 좌표로 갈음한다. 서버가 국내
  /// 밖 좌표를 거절하므로, 해외에서 앱을 열었을 때 카드가 오류로 비는 대신
  /// 서울 날씨라도 보이게 한다.
  Future<(double, double)> _resolvePosition() async {
    try {
      final pos = await _location();
      if (_inKorea(pos.latitude, pos.longitude)) {
        return (pos.latitude, pos.longitude);
      }
      debugPrint('[Weather] 국내 범위 밖 위치 → 기본 좌표 사용');
    } catch (_) {
      debugPrint('[Weather] 위치 확인 실패 → 기본 좌표 사용');
    }
    return (_fallbackLat, _fallbackLng);
  }

  static bool _inKorea(double lat, double lng) =>
      lat >= 33.0 && lat <= 43.0 && lng >= 124.0 && lng <= 132.0;

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
