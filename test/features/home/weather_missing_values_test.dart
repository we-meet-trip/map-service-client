import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/features/home/models/weather_data.dart';

/// 서버는 미리 받아 둔 값을 내려주고, 그 값이 너무 오래됐으면 해당 항목을
/// 비워 보낸다. 화면이 그 부재를 견디는지 여기서 고정한다.
///
/// 예전에는 기온이 반드시 있다고 보고 읽었다. 그 전제가 깨지는 순간 카드가
/// 통째로 예외로 죽는데, 그것은 발급처가 잠깐 멈춘 대가로는 너무 크다.
void main() {
  group('WeatherData 부재 처리', () {
    test('기온이 없어도 읽히고, 남은 항목은 살아 있다', () {
      final w = WeatherData.fromJson(const {
        'sky': '맑음',
        'temp_max': 31,
        'temp_min': 24,
        'pop': 30,
        'pm10': 21,
        'pm10_grade': '좋음',
        'attribution': '기상청, 한국환경공단 제공',
      });

      expect(w.temp, isNull);
      expect(w.skyLabel, '맑음');
      expect(w.tempMax, 31);
      expect(w.pm10Grade, '좋음');
    });

    test('기온을 모르면 옷차림을 제안하지 않는다', () {
      // 기본값으로 아무 옷차림이나 내놓으면 사용자는 그것을 오늘 날씨에
      // 맞춘 제안으로 읽는다.
      final w = WeatherData.fromJson(const {'sky': '맑음'});
      expect(w.clothing, isEmpty);
    });

    test('기온이 있으면 그에 맞는 옷차림이 나온다', () {
      final w = WeatherData.fromJson(const {'temp': 30.0});
      expect(w.clothing, isNotEmpty);
      expect(w.clothing, contains('반팔'));
    });

    test('그릴 것이 하나도 없으면 카드를 감추도록 알린다', () {
      final empty = WeatherData.fromJson(const {});
      expect(empty.hasAnything, isFalse);

      final onlyAir = WeatherData.fromJson(const {'pm10': 21});
      expect(onlyAir.hasAnything, isTrue);
    });

    test('강수 형태도 하늘 상태도 없으면 설명이 빈 문자열이다', () {
      // 화면은 이 값이 비면 그 자리를 그리지 않는다.
      final w = WeatherData.fromJson(const {'pm10': 21});
      expect(w.description, isEmpty);
    });
  });

  group('관측 시각 표기', () {
    test('한 시간 넘게 지난 값이면 몇 시 기준인지 밝힌다', () {
      final old = DateTime.now().subtract(const Duration(hours: 3));
      final w = WeatherData.fromJson({
        'temp': 28.0,
        'observed_at': old.toIso8601String(),
      });
      expect(w.observedLabel, '${old.hour}시 기준');
    });

    test('방금 받은 값이면 굳이 밝히지 않는다', () {
      // 늘 붙어 있으면 잡음이 된다.
      final fresh = DateTime.now().subtract(const Duration(minutes: 10));
      final w = WeatherData.fromJson({
        'temp': 28.0,
        'observed_at': fresh.toIso8601String(),
      });
      expect(w.observedLabel, isNull);
    });

    test('시각을 읽을 수 없어도 카드는 살아 있다', () {
      // 시각 하나 때문에 전체가 죽으면 안 된다.
      final w = WeatherData.fromJson(const {
        'temp': 28.0,
        'observed_at': '어제쯤',
      });
      expect(w.temp, 28.0);
      expect(w.observedAt, isNull);
      expect(w.observedLabel, isNull);
    });

    test('미세먼지 측정 시각도 따로 읽는다', () {
      final old = DateTime.now().subtract(const Duration(hours: 2));
      final w = WeatherData.fromJson({
        'pm10': 21,
        'air_observed_at': old.toIso8601String(),
      });
      expect(w.airObservedLabel, '${old.hour}시 기준');
    });
  });
}
