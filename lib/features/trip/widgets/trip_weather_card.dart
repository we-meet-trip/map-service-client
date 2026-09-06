import 'package:flutter/material.dart';
import '../models/trip_forecast.dart';

class TripWeatherCard extends StatelessWidget {
  const TripWeatherCard({
    super.key,
    required this.forecast,
    required this.date,
  });
  final Future<TripForecast?> forecast;
  final DateTime date;

  String _kst(DateTime value) {
    final kst = value.toUtc().add(const Duration(hours: 9));
    return '${kst.month}/${kst.day} ${kst.hour.toString().padLeft(2, '0')}:${kst.minute.toString().padLeft(2, '0')} KST';
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<TripForecast?>(
    future: forecast,
    builder: (context, snapshot) {
      final key = forecastDateKey(date);
      final data = snapshot.data;
      final day = data?.forDate(key);
      String detail;
      if (snapshot.connectionState != ConnectionState.done) {
        detail = '여행 날짜의 저장 예보를 확인하고 있어요.';
      } else if (snapshot.hasError || day == null) {
        detail = data?.missingReasons[key] == 'out_of_range'
            ? '기상청 예보 제공 기간 밖이에요. 여행일이 가까워지면 다시 확인해주세요.'
            : '이 날짜·지역의 최신 예보를 확인할 수 없어요. 일부 자료가 없거나 갱신이 지연될 수 있어요.';
      } else {
        final source = day.source == 'short_term' ? '단기예보' : '중기예보';
        detail =
            '${day.sky ?? '하늘상태 미제공'} · 최저 ${day.min == null ? '미제공' : '${day.min}°'} / 최고 ${day.max == null ? '미제공' : '${day.max}°'}\n'
            '강수확률 ${day.precipitation == null ? '미제공' : '${day.precipitation}%'} · 기상청 $source';
        if (data!.regionFallback) detail += '\n요청 지역 대신 광역 대표 지역의 예보예요.';
        if (day.sourceAt != null) detail += '\n발표 ${_kst(day.sourceAt!)}';
        if (day.capturedAt != null) detail += ' · 수집 ${_kst(day.capturedAt!)}';
      }
      return Semantics(
        container: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F7FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$key 여행지 날씨',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(detail, style: const TextStyle(fontSize: 12, height: 1.5)),
            ],
          ),
        ),
      );
    },
  );
}
