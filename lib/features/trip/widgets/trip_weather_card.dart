import 'dart:async';
import 'package:flutter/material.dart';
import '../models/trip_forecast.dart';

class TripWeatherCard extends StatefulWidget {
  const TripWeatherCard({
    super.key,
    required this.forecast,
    required this.date,
    this.now,
  });
  final Future<TripForecast?> forecast;
  final DateTime date;

  /// Optional clock for deterministic expiry checks in tests.
  final DateTime Function()? now;

  @override
  State<TripWeatherCard> createState() => _TripWeatherCardState();
}

class _TripWeatherCardState extends State<TripWeatherCard>
    with WidgetsBindingObserver {
  Timer? _expiryTimer;
  DateTime? _scheduledExpiry;
  bool _foreground = true;

  DateTime get _now => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(TripWeatherCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.forecast != widget.forecast ||
        oldWidget.date != widget.date ||
        oldWidget.now != widget.now) {
      _cancelExpiry();
    }
  }

  void _cancelExpiry() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _scheduledExpiry = null;
  }

  void _scheduleExpiry(DateTime? expiresAt) {
    if (!_foreground || expiresAt == null || !expiresAt.isAfter(_now)) {
      _cancelExpiry();
      return;
    }
    if (_scheduledExpiry == expiresAt && _expiryTimer?.isActive == true) return;
    _cancelExpiry();
    _scheduledExpiry = expiresAt;
    _expiryTimer = Timer(expiresAt.difference(_now), () {
      _cancelExpiry();
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _cancelExpiry();
    if (_foreground && mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelExpiry();
    super.dispose();
  }

  String _missingDetail(String? reason) => switch (reason) {
    'out_of_range' => '기상청 예보 제공 기간 밖이에요. 여행일이 가까워지면 다시 확인해주세요.',
    'expired' => '저장 예보의 유효 기간이 지났어요. 최신 자료를 다시 확인해주세요.',
    'freshness_unknown' => '저장 예보의 유효 기간을 확인할 수 없어요. 최신 자료를 다시 확인해주세요.',
    _ => '이 날짜·지역의 최신 예보를 확인할 수 없어요. 일부 자료가 없거나 갱신이 지연될 수 있어요.',
  };

  String _kst(DateTime value) {
    final kst = value.toUtc().add(const Duration(hours: 9));
    return '${kst.month}/${kst.day} ${kst.hour.toString().padLeft(2, '0')}:${kst.minute.toString().padLeft(2, '0')} KST';
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<TripForecast?>(
    future: widget.forecast,
    builder: (context, snapshot) {
      final key = forecastDateKey(widget.date);
      final data = snapshot.data;
      final now = _now;
      final day = data?.forDate(key, now: now);
      _scheduleExpiry(
        snapshot.connectionState == ConnectionState.done && !snapshot.hasError
            ? day?.expiresAt
            : null,
      );
      String detail;
      if (snapshot.connectionState != ConnectionState.done) {
        detail = '여행 날짜의 저장 예보를 확인하고 있어요.';
      } else if (snapshot.hasError || day == null) {
        detail = _missingDetail(
          snapshot.hasError
              ? null
              : data?.unavailableReasonForDate(key, now: now),
        );
      } else {
        final source = switch (day.source) {
          'short_term' => '기상청 단기예보',
          'mid_land' || 'mid_temp' || 'mid_land+mid_temp' => '기상청 중기예보',
          _ => '출처 확인 안 됨',
        };
        detail =
            '${day.sky ?? '하늘상태 미제공'} · 최저 ${day.min == null ? '미제공' : '${day.min}°'} / 최고 ${day.max == null ? '미제공' : '${day.max}°'}\n'
            '강수확률 ${day.precipitation == null ? '미제공' : '${day.precipitation}%'} · $source';
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
