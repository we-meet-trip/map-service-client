import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../models/weather_data.dart';

class WeatherService {
  static const _cacheDuration = Duration(minutes: 30);
  static WeatherData? _cache;
  static DateTime? _cacheTime;

  Future<WeatherData> fetchWeather() async {
    if (_cache != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      return _cache!;
    }

    // data.go.kr 인증키 (디코딩 후 Uri 빌더에 전달)
    final key = Uri.decodeComponent(dotenv.env['KMA_API_KEY'] ?? '');
    final pos = await _location();
    var grid = _latLonToGrid(pos.latitude, pos.longitude);
    // 한국 격자 범위(nx: 1~149, ny: 1~253) 벗어나면 서울 기본값 사용
    if ((grid['nx']! < 1 || grid['nx']! > 149) ||
        (grid['ny']! < 1 || grid['ny']! > 253)) {
      debugPrint('[WeatherAPI] 좌표 범위 초과 (lat=${pos.latitude}, lon=${pos.longitude}) → 서울 기본값 사용');
      grid = {'nx': 60, 'ny': 127};
    }
    final sido = _sidoFromLatLon(pos.latitude, pos.longitude);

    final nowDt = _ultraNowBaseDateTime();
    final fcstDt = _forecastBaseDateTime();

    final results = await Future.wait([
      // 1. 초단기실황: 현재 기온(T1H), 강수형태(PTY)
      http.get(_kmaUri('getUltraSrtNcst', {
        'base_date': nowDt.date,
        'base_time': nowDt.time,
        'nx': '${grid['nx']}',
        'ny': '${grid['ny']}',
        'numOfRows': '20',
        'pageNo': '1',
      }, key)),
      // 2. 단기예보: 최고/최저기온(TMX/TMN), 하늘상태(SKY), 강수확률(POP)
      http.get(_kmaUri('getVilageFcst', {
        'base_date': fcstDt.date,
        'base_time': fcstDt.time,
        'nx': '${grid['nx']}',
        'ny': '${grid['ny']}',
        'numOfRows': '500',
        'pageNo': '1',
      }, key)),
      // 3. 에어코리아: 미세먼지(PM10/PM25)
      http.get(_airUri(sido, key)),
    ]);

    debugPrint('[WeatherAPI 0 URL] ${_kmaUri('getUltraSrtNcst', {
      'base_date': nowDt.date, 'base_time': nowDt.time,
      'nx': '${grid['nx']}', 'ny': '${grid['ny']}', 'numOfRows': '20', 'pageNo': '1',
    }, key)}');
    for (var i = 0; i < results.length; i++) {
      debugPrint('[WeatherAPI $i] ${results[i].statusCode} ${results[i].body}');
    }

    if (results[0].statusCode == 429 || results[1].statusCode == 429) {
      throw Exception('기상청 API 호출 한도 초과 — 잠시 후 다시 시도해주세요.');
    }
    if (results[0].statusCode != 200) {
      throw Exception('초단기실황 API 오류 (${results[0].statusCode})');
    }
    if (results[1].statusCode != 200) {
      throw Exception('단기예보 API 오류 (${results[1].statusCode})');
    }
    if (results[2].statusCode != 200) {
      throw Exception('에어코리아 API 오류 (${results[2].statusCode})');
    }

    // ── 초단기실황 파싱 ──────────────────────────────────────────────────────
    final nowJson = jsonDecode(results[0].body) as Map<String, dynamic>;
    _checkKmaResult(nowJson, '초단기실황');
    final nowItems = (nowJson['response']['body']['items']['item'] as List)
        .cast<Map<String, dynamic>>();
    final nowMap = {
      for (final i in nowItems) i['category'] as String: i['obsrValue'] as String
    };

    final t1h = double.tryParse(nowMap['T1H'] ?? '') ?? 0.0;
    final pty = int.tryParse(nowMap['PTY'] ?? '') ?? 0;

    // ── 단기예보 파싱 ────────────────────────────────────────────────────────
    final fcstJson = jsonDecode(results[1].body) as Map<String, dynamic>;
    _checkKmaResult(fcstJson, '단기예보');
    final fcstItems = (fcstJson['response']['body']['items']['item'] as List)
        .cast<Map<String, dynamic>>();

    final todayStr = _fmtDate(DateTime.now());
    final todayItems = fcstItems
        .where((item) => item['fcstDate'] as String == todayStr)
        .toList();

    double? tmx, tmn;
    int? sky, pop;

    // 현재 시각 기준 가장 가까운 3시간 단위 슬롯
    final now = DateTime.now();
    final targetTimeInt = (now.hour ~/ 3) * 3 * 100;

    for (final item in todayItems) {
      final cat = item['category'] as String;
      final val = item['fcstValue'] as String;
      final fcstTimeInt = int.tryParse(item['fcstTime'] as String) ?? 0;

      if (cat == 'TMX') tmx ??= double.tryParse(val);
      if (cat == 'TMN') tmn ??= double.tryParse(val);
      if (cat == 'SKY' && sky == null && fcstTimeInt >= targetTimeInt) {
        sky = int.tryParse(val);
      }
      if (cat == 'POP' && pop == null && fcstTimeInt >= targetTimeInt) {
        pop = int.tryParse(val);
      }
    }

    // 당일 데이터가 없을 때 폴백 (늦은 밤 등)
    if (sky == null) {
      final anysky = todayItems.where((i) => i['category'] == 'SKY');
      sky = anysky.isNotEmpty ? int.tryParse(anysky.first['fcstValue'] as String) ?? 1 : 1;
    }

    // ── 에어코리아 파싱 ──────────────────────────────────────────────────────
    final airJson = jsonDecode(results[2].body) as Map<String, dynamic>;
    final rawItems = airJson['response']['body']['items'];
    final List<Map<String, dynamic>> airList;
    if (rawItems is List) {
      airList = rawItems.cast<Map<String, dynamic>>();
    } else if (rawItems is Map && rawItems['item'] is List) {
      airList = (rawItems['item'] as List).cast<Map<String, dynamic>>();
    } else {
      airList = [];
    }

    double pm10 = 0, pm25 = 0;
    for (final item in airList) {
      final v10 = double.tryParse(item['pm10Value'] as String? ?? '');
      final v25 = double.tryParse(item['pm25Value'] as String? ?? '');
      if (v10 != null && v25 != null) {
        pm10 = v10;
        pm25 = v25;
        break;
      }
    }

    final data = WeatherData(
      temp: t1h,
      tempMax: tmx ?? t1h,
      tempMin: tmn ?? t1h,
      sky: sky,
      pty: pty,
      pop: pop ?? 0,
      pm10: pm10,
      pm25: pm25,
    );
    _cache = data;
    _cacheTime = DateTime.now();
    return data;
  }

  // ── 헬퍼 ─────────────────────────────────────────────────────────────────

  void _checkKmaResult(Map<String, dynamic> json, String name) {
    final header = json['response']?['header'] as Map<String, dynamic>?;
    final code = header?['resultCode'] as String?;
    if (code != null && code != '00') {
      throw Exception('$name 오류 ($code): ${header?['resultMsg']}');
    }
  }

  Uri _kmaUri(String endpoint, Map<String, String> params, String key) {
    return Uri.https(
      'apis.data.go.kr',
      '/1360000/VilageFcstInfoService_2.0/$endpoint',
      {'serviceKey': key, 'dataType': 'JSON', ...params},
    );
  }

  Uri _airUri(String sido, String key) {
    return Uri.https(
      'apis.data.go.kr',
      '/B552584/ArpltnInforInqireSvc/getCtprvnRltmMesureDnsty',
      {
        'serviceKey': key,
        'returnType': 'json',
        'numOfRows': '5',
        'pageNo': '1',
        'sidoName': sido,
        'ver': '1.0',
      },
    );
  }

  // 위경도 → 기상청 격자 좌표 (LCC 도법)
  Map<String, int> _latLonToGrid(double lat, double lon) {
    const double re = 6371.00877 / 5.0;
    const double slat1 = 30.0 * pi / 180;
    const double slat2 = 60.0 * pi / 180;
    const double olon = 126.0 * pi / 180;
    const double olat = 38.0 * pi / 180;
    const double xo = 43.0;
    const double yo = 136.0;

    final double sn = log(cos(slat1) / cos(slat2)) /
        log(tan(pi * 0.25 + slat2 * 0.5) / tan(pi * 0.25 + slat1 * 0.5));
    final double sf =
        pow(tan(pi * 0.25 + slat1 * 0.5), sn).toDouble() * cos(slat1) / sn;
    final double ro =
        re * sf / pow(tan(pi * 0.25 + olat * 0.5), sn).toDouble();

    final double ra =
        re * sf / pow(tan(pi * 0.25 + lat * pi / 180 * 0.5), sn).toDouble();
    double theta = lon * pi / 180 - olon;
    if (theta > pi) theta -= 2 * pi;
    if (theta < -pi) theta += 2 * pi;
    theta *= sn;

    return {
      'nx': (ra * sin(theta) + xo + 0.5).floor(),
      'ny': (ro - ra * cos(theta) + yo + 0.5).floor(),
    };
  }

  // 위경도 → 시도명 (에어코리아 조회용)
  String _sidoFromLatLon(double lat, double lon) {
    if (lat >= 33.1 && lat <= 33.6 && lon >= 126.1 && lon <= 127.0) return '제주';
    if (lat >= 36.4 && lat <= 36.6 && lon >= 127.2 && lon <= 127.4) return '세종';
    if (lat >= 35.1 && lat <= 35.3 && lon >= 126.7 && lon <= 127.0) return '광주';
    if (lat >= 35.4 && lat <= 35.6 && lon >= 129.1 && lon <= 129.5) return '울산';
    if (lat >= 35.0 && lat <= 35.4 && lon >= 128.8 && lon <= 129.3) return '부산';
    if (lat >= 35.8 && lat <= 36.0 && lon >= 128.4 && lon <= 128.8) return '대구';
    if (lat >= 36.2 && lat <= 36.5 && lon >= 127.3 && lon <= 127.5) return '대전';
    if (lat >= 37.3 && lat <= 37.6 && lon >= 126.4 && lon <= 126.8) return '인천';
    if (lat >= 37.4 && lat <= 37.7 && lon >= 126.8 && lon <= 127.2) return '서울';
    if (lat >= 37.1 && lat <= 38.3 && lon >= 126.4 && lon <= 128.0) return '경기';
    if (lat >= 37.1 && lat <= 38.6 && lon >= 127.7 && lon <= 129.4) return '강원';
    if (lat >= 36.5 && lat <= 37.1 && lon >= 127.3 && lon <= 128.5) return '충북';
    if (lat >= 36.0 && lat <= 37.1 && lon >= 125.8 && lon <= 127.7) return '충남';
    if (lat >= 35.5 && lat <= 36.1 && lon >= 126.4 && lon <= 127.8) return '전북';
    if (lat >= 34.2 && lat <= 35.5 && lon >= 125.8 && lon <= 127.9) return '전남';
    if (lat >= 35.5 && lat <= 37.2 && lon >= 128.0 && lon <= 130.0) return '경북';
    if (lat >= 34.8 && lat <= 35.8 && lon >= 127.6 && lon <= 129.5) return '경남';
    return '서울';
  }

  // 초단기실황 기준시각 (매시 40분 발표, 45분 후 제공)
  ({String date, String time}) _ultraNowBaseDateTime() {
    final now = DateTime.now();
    if (now.minute >= 45) {
      return (date: _fmtDate(now), time: '${now.hour.toString().padLeft(2, '0')}40');
    }
    final prev = now.subtract(const Duration(hours: 1));
    return (date: _fmtDate(prev), time: '${prev.hour.toString().padLeft(2, '0')}40');
  }

  // 단기예보 기준시각 (0200/0500/0800/1100/1400/1700/2000/2300, 10분 후 제공)
  ({String date, String time}) _forecastBaseDateTime() {
    final now = DateTime.now();
    const issueTimes = [2, 5, 8, 11, 14, 17, 20, 23];
    int? foundHour;
    for (final h in issueTimes) {
      if (now.hour > h || (now.hour == h && now.minute >= 10)) {
        foundHour = h;
      }
    }
    if (foundHour != null) {
      return (
        date: _fmtDate(now),
        time: '${foundHour.toString().padLeft(2, '0')}00',
      );
    }
    // 오전 2시 10분 이전 → 전날 2300 발표
    final yesterday = now.subtract(const Duration(days: 1));
    return (date: _fmtDate(yesterday), time: '2300');
  }

  String _fmtDate(DateTime dt) =>
      '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';

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

    final last = await Geolocator.getLastKnownPosition();
    if (last != null) return last;

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('위치 정보 요청 시간이 초과됐어요.'),
    );
  }
}
