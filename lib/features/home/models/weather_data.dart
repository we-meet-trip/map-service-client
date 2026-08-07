/// 홈 화면 날씨 카드가 그리는 값.
///
/// 서버가 실황·예보·대기오염을 합쳐 한 형태로 내려준 것을 그대로 담는다.
/// 지금 기온만 항상 있고 나머지는 없을 수 있다 — 예보가 아직 없거나 대기
/// 정보를 못 받은 상태가 정상적으로 존재하므로, 화면은 없는 항목의 줄을
/// 통째로 생략한다.
class WeatherData {
  /// 지금 기온(℃).
  final double temp;

  /// 강수 형태 코드. 0이면 강수 없음. 아이콘과 설명을 정할 때 먼저 본다.
  final int? pty;

  /// 하늘 상태 텍스트(예: "맑음"). 예보가 없으면 비어 있다.
  final String? skyLabel;

  /// 어제 같은 시간대 대비 기온 차(℃). 어제 기록이 없으면 비어 있고,
  /// 그때 화면은 비교 문구를 그리지 않는다.
  final double? yesterdayDiff;

  final int? tempMax;
  final int? tempMin;

  /// 강수 확률(%).
  final int? pop;

  final int? pm10;
  final int? pm25;

  /// 서버가 매긴 미세먼지 등급. 같은 기준을 서버와 화면 양쪽에 두면 서서히
  /// 갈라지므로, 화면은 계산하지 않고 받은 값을 그대로 쓴다.
  final String? pm10Grade;
  final String? pm25Grade;

  /// 카드 하단 출처 표기.
  final String attribution;

  const WeatherData({
    required this.temp,
    this.pty,
    this.skyLabel,
    this.yesterdayDiff,
    this.tempMax,
    this.tempMin,
    this.pop,
    this.pm10,
    this.pm25,
    this.pm10Grade,
    this.pm25Grade,
    this.attribution = '기상청, 한국환경공단 제공',
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) => WeatherData(
        temp: (json['temp'] as num).toDouble(),
        pty: json['pty'] is num ? (json['pty'] as num).toInt() : null,
        skyLabel: json['sky'] is String ? json['sky'] as String : null,
        yesterdayDiff: json['yesterday_diff'] is num
            ? (json['yesterday_diff'] as num).toDouble()
            : null,
        tempMax:
            json['temp_max'] is num ? (json['temp_max'] as num).toInt() : null,
        tempMin:
            json['temp_min'] is num ? (json['temp_min'] as num).toInt() : null,
        pop: json['pop'] is num ? (json['pop'] as num).toInt() : null,
        pm10: json['pm10'] is num ? (json['pm10'] as num).toInt() : null,
        pm25: json['pm25'] is num ? (json['pm25'] as num).toInt() : null,
        pm10Grade:
            json['pm10_grade'] is String ? json['pm10_grade'] as String : null,
        pm25Grade:
            json['pm25_grade'] is String ? json['pm25_grade'] as String : null,
        attribution: json['attribution'] is String
            ? json['attribution'] as String
            : '기상청, 한국환경공단 제공',
      );

  /// 날씨 한 줄 설명. 비가 오는지가 하늘 상태보다 앞선다.
  String get description {
    switch (pty) {
      case 1:
        return '비';
      case 2:
        return '비/눈';
      case 3:
        return '눈';
      case 4:
        return '소나기';
    }
    return skyLabel ?? '';
  }

  /// 카드에 띄울 그림. 강수가 있으면 그것을 먼저 쓰고, 없으면 하늘 상태를 본다.
  String get iconAsset {
    switch (pty) {
      case 1:
      case 4:
        return 'assets/images/weather/rainy.png';
      case 2:
        return 'assets/images/weather/sleet.png';
      case 3:
        return 'assets/images/weather/snowy.png';
    }
    final sky = skyLabel;
    if (sky == null) return 'assets/images/weather/cloudy.png';
    if (sky.contains('맑')) return 'assets/images/weather/sunny.png';
    if (sky.contains('구름')) {
      return 'assets/images/weather/partly_cloudy.png';
    }
    return 'assets/images/weather/cloudy.png';
  }

  /// 어제 대비 안내 문구. 비교할 기록이 없으면 비어 있다.
  String? get yesterdayLabel {
    final diff = yesterdayDiff;
    if (diff == null) return null;
    // 0.5도 미만 차이는 같은 기온으로 본다 — 0.2도 차이를 "높아요"라고 하면
    // 체감과 어긋난다.
    if (diff.abs() < 0.5) return '어제와 기온이 같아요';
    final amount = diff.abs().round();
    return diff > 0 ? '어제보다 $amount°C 높아요' : '어제보다 $amount°C 낮아요';
  }

  /// 기온에 맞춘 옷차림 제안. 화면에서만 쓰는 표라 서버를 거치지 않는다.
  List<String> get clothing {
    if (temp >= 28) return ['반팔', '반바지', '샌들'];
    if (temp >= 23) return ['반팔', '얇은 긴바지'];
    if (temp >= 20) return ['얇은 긴팔', '긴바지'];
    if (temp >= 17) return ['긴팔', '얇은 자켓', '청바지'];
    if (temp >= 12) return ['맨투맨', '자켓', '긴바지'];
    if (temp >= 9) return ['자켓', '기모 티', '청바지'];
    if (temp >= 5) return ['코트', '기모 티', '긴바지'];
    return ['패딩', '기모 티', '기모 바지'];
  }
}
