import 'dart:convert';
import 'package:http/http.dart' as http;

// ─── Request ──────────────────────────────────────────────────

class TripGenerateRequest {
  final DateTime startDate;
  final DateTime endDate;
  final int activeStartHour;
  final int activeEndHour;
  final int minBudget;
  final int maxBudget;
  final List<String> themes;
  final String transport;
  final String province;
  final String city;

  const TripGenerateRequest({
    required this.startDate,
    required this.endDate,
    required this.activeStartHour,
    required this.activeEndHour,
    required this.minBudget,
    required this.maxBudget,
    required this.themes,
    required this.transport,
    required this.province,
    required this.city,
  });

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'schedule': {
          'start_date': _fmtDate(startDate),
          'end_date': _fmtDate(endDate),
          'active_start_hour': activeStartHour,
          'active_end_hour': activeEndHour,
        },
        'budget': {
          'min': minBudget,
          'max': maxBudget,
        },
        'themes': themes,
        'transport': transport,
        'location': {
          'province': province,
          'city': city,
        },
      };
}

// ─── Response ─────────────────────────────────────────────────

class TripTransportToNext {
  final String type;
  final String label;
  final int durationMinutes;
  final double distanceKm;

  const TripTransportToNext({
    required this.type,
    required this.label,
    required this.durationMinutes,
    required this.distanceKm,
  });

  factory TripTransportToNext.fromJson(Map<String, dynamic> json) =>
      TripTransportToNext(
        type: json['type'] as String,
        label: json['label'] as String,
        durationMinutes: json['duration_minutes'] as int,
        distanceKm: (json['distance_km'] as num).toDouble(),
      );
}

class TripStop {
  final int order;
  final String name;
  final String address;
  final String time; // HH:mm
  final double latitude;
  final double longitude;
  final TripTransportToNext? transportToNext;

  const TripStop({
    required this.order,
    required this.name,
    required this.address,
    required this.time,
    required this.latitude,
    required this.longitude,
    this.transportToNext,
  });

  factory TripStop.fromJson(Map<String, dynamic> json) => TripStop(
        order: json['order'] as int,
        name: json['name'] as String,
        address: json['address'] as String,
        time: json['time'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        transportToNext: json['transport_to_next'] != null
            ? TripTransportToNext.fromJson(
                json['transport_to_next'] as Map<String, dynamic>)
            : null,
      );
}

class WeatherForecast {
  final String date;
  final String condition; // sunny | cloudy | rainy | snowy
  final int tempHigh;
  final int tempLow;
  final int precipitationProbability;

  const WeatherForecast({
    required this.date,
    required this.condition,
    required this.tempHigh,
    required this.tempLow,
    required this.precipitationProbability,
  });

  factory WeatherForecast.fromJson(Map<String, dynamic> json) => WeatherForecast(
        date: json['date'] as String,
        condition: json['condition'] as String,
        tempHigh: json['temp_high'] as int,
        tempLow: json['temp_low'] as int,
        precipitationProbability: json['precipitation_probability'] as int,
      );
}

class TripGenerateResponse {
  final String tripId;
  final int totalDurationMinutes;
  final List<TripStop> stops;
  final List<WeatherForecast> weatherForecast;

  const TripGenerateResponse({
    required this.tripId,
    required this.totalDurationMinutes,
    required this.stops,
    required this.weatherForecast,
  });

  factory TripGenerateResponse.fromJson(Map<String, dynamic> json) =>
      TripGenerateResponse(
        tripId: json['trip_id'] as String,
        totalDurationMinutes: json['total_duration_minutes'] as int,
        stops: (json['stops'] as List<dynamic>)
            .map((s) => TripStop.fromJson(s as Map<String, dynamic>))
            .toList(),
        weatherForecast: (json['weather_forecast'] as List<dynamic>)
            .map((w) => WeatherForecast.fromJson(w as Map<String, dynamic>))
            .toList(),
      );
}

// ─── Exceptions ───────────────────────────────────────────────

class TripApiException implements Exception {
  final String error;
  final String message;
  final int statusCode;

  const TripApiException({
    required this.error,
    required this.message,
    required this.statusCode,
  });

  @override
  String toString() => '[$statusCode] $error: $message';
}

// ─── Service ─────────────────────────────────────────────────

class TripApiService {
  TripApiService._();
  static final TripApiService instance = TripApiService._();

  static const _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  Future<TripGenerateResponse> generateTrip(TripGenerateRequest request) async {
    final uri = Uri.parse('$_baseUrl/api/v1/trip/generate');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return TripGenerateResponse.fromJson(body);
    }

    throw TripApiException(
      error: body['error'] as String? ?? 'UNKNOWN_ERROR',
      message: body['message'] as String? ?? '알 수 없는 오류가 발생했습니다.',
      statusCode: response.statusCode,
    );
  }
}
