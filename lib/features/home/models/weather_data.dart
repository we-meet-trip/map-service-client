/// 홈 화면 날씨 카드가 그리는 값.
///
/// 서버가 실황·예보·대기오염을 합쳐 한 형태로 내려준 것을 그대로 담는다.
/// **어느 항목이든 없을 수 있다.** 서버는 미리 받아 둔 값을 내려주고, 그
/// 값이 너무 오래됐으면 해당 항목을 비워 보낸다 — 새벽 기온을 지금 기온이라고
/// 보여 주지 않기 위해서다. 화면은 없는 항목의 줄을 통째로 생략한다.
class WeatherData {
  /// 지금 기온(℃). 서버에 신선한 실황이 없으면 비어 있다.
  final double? temp;

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

  /// 기온이 실제로 관측된 시각. 서버가 미리 받아 둔 값이라 지금 시각과
  /// 다를 수 있어, 화면이 "몇 시 기준"인지 밝힐 수 있게 함께 받는다.
  final DateTime? observedAt;

  /// 미세먼지가 실제로 측정된 시각.
  final DateTime? airObservedAt;

  /// 카드 하단 출처 표기.
  final String attribution;

  const WeatherData({
    this.temp,
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
    this.observedAt,
    this.airObservedAt,
    this.attribution = '기상청, 한국환경공단 제공',
  });

  /// 카드에 그릴 것이 하나라도 있는지. 전부 비면 화면은 카드를 감춘다 —
  /// 빈 테두리만 남은 카드는 고장으로 보인다.
  bool get hasAnything =>
      temp != null ||
      skyLabel != null ||
      tempMax != null ||
      tempMin != null ||
      pop != null ||
      pm10 != null ||
      pm25 != null;

  factory WeatherData.fromJson(Map<String, dynamic> json) => WeatherData(
        temp: json['temp'] is num ? (json['temp'] as num).toDouble() : null,
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
        observedAt: _parseTime(json['observed_at']),
        airObservedAt: _parseTime(json['air_observed_at']),
        attribution: json['attribution'] is String
            ? json['attribution'] as String
            : '기상청, 한국환경공단 제공',
      );

  /// 서버가 준 시각 문자열을 읽는다. 읽을 수 없으면 없는 것으로 본다 —
  /// 시각 하나 때문에 카드 전체가 죽으면 안 된다.
  static DateTime? _parseTime(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  /// "16시 기준" 처럼 언제 잰 값인지 밝히는 문구.
  ///
  /// 방금 받은 값이면 굳이 밝히지 않는다 — 늘 붙어 있으면 잡음이 된다.
  /// 한 시간 넘게 지난 값일 때만 내보내, 사용자가 지금 값이 아님을 안다.
  String? get observedLabel => _stamp(observedAt);

  /// 미세먼지 쪽의 같은 문구.
  String? get airObservedLabel => _stamp(airObservedAt);

  static String? _stamp(DateTime? at) {
    if (at == null) return null;
    if (DateTime.now().difference(at) < const Duration(hours: 1)) return null;
    return '${at.hour}시 기준';
  }

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
  ///
  /// 기온을 모르면 아무것도 제안하지 않는다. 기본값으로 아무 옷차림이나
  /// 내놓으면 사용자는 그것을 오늘 날씨에 맞춘 제안으로 읽는다.
  List<String> get clothing {
    final temp = this.temp;
    if (temp == null) return const [];
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
