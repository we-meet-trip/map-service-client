class WeatherData {
  final double temp;
  final double tempMax;
  final double tempMin;
  final int sky; // 기상청: 1=맑음, 3=구름많음, 4=흐림
  final int pty; // 기상청: 0=없음, 1=비, 2=비/눈, 3=눈, 4=소나기
  final int pop;
  final double pm10;
  final double pm25;

  const WeatherData({
    required this.temp,
    required this.tempMax,
    required this.tempMin,
    required this.sky,
    required this.pty,
    required this.pop,
    required this.pm10,
    required this.pm25,
  });

  String get description {
    if (pty == 1) return '비';
    if (pty == 2) return '비/눈';
    if (pty == 3) return '눈';
    if (pty == 4) return '소나기';
    if (sky == 1) return '맑음';
    if (sky == 3) return '구름 많음';
    return '흐림';
  }

  String get iconAsset {
    if (pty == 1 || pty == 4) return 'assets/images/weather/rainy.png';
    if (pty == 2) return 'assets/images/weather/sleet.png';
    if (pty == 3) return 'assets/images/weather/snowy.png';
    if (sky == 1) return 'assets/images/weather/sunny.png';
    if (sky == 3) return 'assets/images/weather/partly_cloudy.png';
    return 'assets/images/weather/cloudy.png';
  }

  String get pm10Label {
    if (pm10 <= 30) return '좋음';
    if (pm10 <= 80) return '보통';
    if (pm10 <= 150) return '나쁨';
    return '매우나쁨';
  }

  String get pm25Label {
    if (pm25 <= 15) return '좋음';
    if (pm25 <= 35) return '보통';
    if (pm25 <= 75) return '나쁨';
    return '매우나쁨';
  }

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
