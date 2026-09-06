/// Stored forecasts use calendar dates in Korea, independently of device timezone.
class TripForecast {
  final String province;
  final String city;
  final bool regionFallback;
  final List<TripForecastDay> daily;
  final Map<String, String> missingReasons;

  const TripForecast({
    required this.province,
    required this.city,
    this.regionFallback = false,
    required this.daily,
    this.missingReasons = const {},
  });

  factory TripForecast.fromJson(Map<String, dynamic> json) => TripForecast(
    province: json['province'] as String? ?? '',
    city: json['city'] as String? ?? '',
    regionFallback: json['region_fallback'] == true,
    daily: (json['daily'] as List? ?? [])
        .whereType<Map>()
        .map((row) => TripForecastDay.fromJson(Map<String, dynamic>.from(row)))
        .toList(),
    missingReasons: (json['missing_reasons'] as Map? ?? {}).map(
      (k, v) => MapEntry('$k', '$v'),
    ),
  );

  TripForecastDay? forDate(String date, {DateTime? now}) {
    for (final day in daily) {
      if (day.date == date &&
          (day.expiresAt == null ||
              day.expiresAt!.isAfter(now ?? DateTime.now()))) {
        return day;
      }
    }
    return null;
  }
}

class TripForecastDay {
  final String date;
  final int? min;
  final int? max;
  final int? precipitation;
  final String? sky;
  final String? source;
  final DateTime? sourceAt;
  final DateTime? capturedAt;
  final DateTime? expiresAt;

  const TripForecastDay({
    required this.date,
    this.min,
    this.max,
    this.precipitation,
    this.sky,
    this.source,
    this.sourceAt,
    this.capturedAt,
    this.expiresAt,
  });

  factory TripForecastDay.fromJson(Map<String, dynamic> json) {
    int? value(String key) {
      final v = json[key];
      return v is num && v.isFinite && v > -900 && v < 900 ? v.round() : null;
    }

    DateTime? timestamp(String key) =>
        DateTime.tryParse(json[key] as String? ?? '');
    final pop = value('precipitation_prob');
    return TripForecastDay(
      date: json['date'] as String? ?? '',
      min: value('temp_min'),
      max: value('temp_max'),
      precipitation: pop != null && pop >= 0 && pop <= 100 ? pop : null,
      sky: json['sky_condition'] as String?,
      source: json['source'] as String?,
      sourceAt: timestamp('source_at'),
      capturedAt: timestamp('captured_at'),
      expiresAt: timestamp('expires_at'),
    );
  }
}

String forecastDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
