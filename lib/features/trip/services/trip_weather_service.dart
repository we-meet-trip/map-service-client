import '../../../core/api/api_client.dart';
import '../models/trip_forecast.dart';

class TripWeatherService {
  Future<TripForecast> fetch({
    required String province,
    required String city,
    required DateTime start,
    required DateTime end,
  }) async {
    final body = await ApiClient.instance.get(
      '/api/v1/weather/forecast',
      query: {
        'province': province,
        'city': city,
        'date_start': forecastDateKey(start),
        'date_end': forecastDateKey(end),
      },
      timeout: const Duration(seconds: 15),
    );
    return TripForecast.fromJson(body);
  }
}
