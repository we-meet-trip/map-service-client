import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/theme/app_icons.dart';
import '../../../common/theme/app_text_styles.dart';
import '../../../common/widgets/app_loading_indicator.dart';
import '../../trip/widgets/trip_card.dart';
import '../models/weather_data.dart';
import '../services/weather_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _focusedDate = DateTime.now();
  WeatherData? _weather;
  bool _weatherLoading = true;
  String? _weatherError;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && mounted) {
        final proceed = await _showLocationPermissionSheet();
        if (!proceed) {
          if (mounted) setState(() { _weatherLoading = false; });
          return;
        }
      }
      final data = await WeatherService().fetchWeather();
      if (mounted) setState(() { _weather = data; _weatherLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _weatherError = e.toString(); _weatherLoading = false; });
    }
  }

  Future<bool> _showLocationPermissionSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.neutralScale[100],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppColors.primaryScale[0],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: PhosphorIcon(
                  PhosphorIconsRegular.mapPin,
                  color: AppColors.primaryScale[500],
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('위치 정보 허용', style: AppTextStyles.heading2),
            const SizedBox(height: 8),
            Text(
              '현재 위치의 날씨 정보를 제공하기 위해\n위치 접근 권한이 필요해요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.neutralScale[400], height: 1.5),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => Navigator.pop(ctx, true),
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.secondaryScale[900]!, AppColors.secondaryScale[500]!],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Center(
                  child: Text('허용하기',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => Navigator.pop(ctx, false),
              child: Text('나중에',
                  style: TextStyle(fontSize: 15, color: AppColors.neutralScale[300])),
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  void _shiftWeek(int delta) {
    setState(() {
      _focusedDate = _focusedDate.add(Duration(days: delta * 7));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Greeting(),
              const SizedBox(height: 24),
              _TripCard(),
              const SizedBox(height: 16),
              _WeekCalendar(
                focusedDate: _focusedDate,
                onShiftWeek: _shiftWeek,
                onDateTapped: (date) => setState(() => _focusedDate = date),
              ),
              const SizedBox(height: 16),
              _WeatherCard(
                weather: _weather,
                loading: _weatherLoading,
                error: _weatherError,
                onRetry: _loadWeather,
              ),
              const SizedBox(height: 16),
              _BikeScooterBanner(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 인사 섹션 ────────────────────────────────────────────────────────────────

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 100,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '안녕하세요!',
                  style: AppTextStyles.body6.copyWith(
                    color: AppColors.primaryScale[500],
                  ),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '보라돌이동글이',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.neutralScale[600],
                        ),
                      ),
                      TextSpan(
                        text: ' 님',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: AppColors.neutralScale[400],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            bottom: -8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SpeechBubble(),
                ),
                const SizedBox(width: 8),
                SvgPicture.asset(
                  'assets/svg/character.svg',
                  width: 100,
                  height: 100,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SpeechBubblePainter(AppColors.secondaryScale[700]!),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 18, 4),
        child: Text(
          '좋은 아침이에요!',
          style: AppTextStyles.body8.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

class _SpeechBubblePainter extends CustomPainter {
  final Color color;
  const _SpeechBubblePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const tailW = 9.0;
    final bodyW = size.width - tailW;
    final r = size.height / 2;
    final paint = Paint()..color = color;

    // 알약형 본체 (왼쪽 끝 ~ bodyW)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, bodyW, size.height),
        Radius.circular(r),
      ),
      paint,
    );

    // 오른쪽 위 45° 꼬리 — (cos45, -sin45) 방향
    const double d = 0.7071; // cos/sin 45°
    const double L = 14.0;   // 꼬리 길이
    const double w = 6.0;    // base 반폭
    final cx = bodyW - 5.0;  // base 중심 x (pill 안쪽 6px 겹침)
    final cy = size.height * 0.5; // base 중심 y

    canvas.drawPath(
      Path()
        ..moveTo(cx - w * d, cy - w * d) // base 위쪽 점
        ..lineTo(cx + L * d, cy - L * d) // 꼬리 끝 (오른쪽 위)
        ..lineTo(cx + w * d, cy + w * d) // base 아래쪽 점
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SpeechBubblePainter oldDelegate) => oldDelegate.color != color;
}

// ─── 여행 카드 ────────────────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  const _TripCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondaryScale[900]!,
            AppColors.secondaryScale[500]!,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '속초 우정여행',
                    style: AppTextStyles.body4.copyWith(color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(3.1415926535897932),
                    child: AppIcon(SvgIcons.chevronLeft, size: 12, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '예정된 일정',
                style: AppTextStyles.body9.copyWith(
                  color: Colors.white.withAlpha(178),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            'D-3',
            style: AppTextStyles.title1.copyWith(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 자전거·킥보드 위치 배너 ──────────────────────────────────────────────────

class _BikeScooterBanner extends StatelessWidget {
  const _BikeScooterBanner();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/bike-scooter'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.neutralScale[0],
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondaryScale[900]!.withAlpha(15),
              blurRadius: 10,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '자전거·킥보드 위치',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.neutralScale[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '가까운 단거리 이동',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.savedBadgeFar,
                    ),
                  ),
                ],
              ),
            ),
            Image.asset(
              'assets/images/transport/scooter_location.png',
              width: 62,
              height: 62,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 주간 캘린더 ──────────────────────────────────────────────────────────────

class _WeekCalendar extends StatelessWidget {
  final DateTime focusedDate;
  final void Function(int delta) onShiftWeek;
  final void Function(DateTime) onDateTapped;

  const _WeekCalendar({
    required this.focusedDate,
    required this.onShiftWeek,
    required this.onDateTapped,
  });

  static const _dayLabels = ['일', '월', '화', '수', '목', '금', '토'];

  List<DateTime> _weekDays() {
    final weekday = focusedDate.weekday % 7;
    final sunday = focusedDate.subtract(Duration(days: weekday));
    return List.generate(7, (i) => sunday.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final week = _weekDays();
    final today = DateTime.now();
    final y = focusedDate.year;
    final m = focusedDate.month;
    final d = focusedDate.day;

    return TripCard(
      child: Column(
        children: [
          // 헤더
          Row(
            children: [
              Text(
                '$y년 $m월 $d일',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutralScale[600],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => onShiftWeek(-1),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: AppIcon(
                    SvgIcons.chevronLeft,
                    size: 12,
                    color: AppColors.neutralScale[300],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => onShiftWeek(1),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(3.1415926535897932),
                    child: AppIcon(
                      SvgIcons.chevronLeft,
                      size: 12,
                      color: AppColors.neutralScale[300],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 요일 + 날짜 통합 셀
          Row(
            children: List.generate(7, (i) {
              final date = week[i];
              final isSelected = date.year == focusedDate.year &&
                  date.month == focusedDate.month &&
                  date.day == focusedDate.day;
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onDateTapped(date),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _DayCell(
                      label: _dayLabels[i],
                      day: date.day,
                      isSelected: isSelected,
                      isToday: isToday,
                      columnIndex: i,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

}

class _DayCell extends StatelessWidget {
  final String label;
  final int day;
  final bool isSelected;
  final bool isToday;
  final int columnIndex;

  const _DayCell({
    required this.label,
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.columnIndex,
  });

  Color _labelColor() {
    if (columnIndex == 0) return AppColors.redScale[400]!;
    if (columnIndex == 6) return AppColors.blueScale[500]!;
    return AppColors.neutralScale[300]!;
  }

  Color _dateColor() {
    if (isToday) return AppColors.primaryScale[500]!;
    if (columnIndex == 0) return AppColors.redScale[400]!;
    if (columnIndex == 6) return AppColors.blueScale[500]!;
    return AppColors.neutralScale[600]!;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: isSelected ? const EdgeInsets.symmetric(horizontal: 4) : EdgeInsets.zero,
      decoration: isSelected
          ? BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(30),
            )
          : null,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _labelColor(),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$day',
            style: TextStyle(
              fontSize: 13,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              color: _dateColor(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 날씨 카드 ────────────────────────────────────────────────────────────────

class _WeatherCard extends StatelessWidget {
  final WeatherData? weather;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  const _WeatherCard({
    required this.weather,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return TripCard(
        child: const SizedBox(
          height: 120,
          child: Center(child: AppLoadingIndicator()),
        ),
      );
    }

    if (error != null || weather == null) {
      return TripCard(
        child: SizedBox(
          height: 120,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('날씨 정보를 불러올 수 없어요',
                    style: TextStyle(fontSize: 13, color: AppColors.neutralScale[300])),
                const SizedBox(height: 4),
                Text(error ?? '', style: TextStyle(fontSize: 11, color: AppColors.neutralScale[200])),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onRetry,
                  child: Text('다시 시도',
                      style: TextStyle(fontSize: 13, color: AppColors.primaryScale[500],
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final w = weather!;
    return TripCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 온도 + 날씨 이모지
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('${w.temp.round()}°C',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 10),
                      Text(w.description,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  // 어제 같은 시간대 기록이 있을 때만 비교 문구를 그린다.
                  if (w.yesterdayLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(w.yesterdayLabel!,
                        style: TextStyle(fontSize: 16, color: AppColors.neutralScale[400])),
                  ],
                ],
              ),
              const Spacer(),
              Image.asset(w.iconAsset, width: 88, height: 88),
            ],
          ),
          const SizedBox(height: 8),
          // 추천 스타일
          Text('추천 스타일',
              style: TextStyle(fontSize: 13, color: AppColors.neutralScale[300])),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: w.clothing.map((c) => _ClothingItem(label: c)).toList(),
            ),
          ),
          const SizedBox(height: 20),
          // 날씨 세부 정보 — 두 컬럼 + 구분선
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (w.tempMax != null)
                      Text('최고  ${w.tempMax}°C',
                          style: TextStyle(fontSize: 13, color: AppColors.neutralScale[500])),
                    if (w.tempMax != null && w.tempMin != null)
                      const SizedBox(height: 6),
                    if (w.tempMin != null)
                      Text('최저  ${w.tempMin}°C',
                          style: TextStyle(fontSize: 13, color: AppColors.neutralScale[500])),
                  ],
                ),
                const SizedBox(width: 16),
                VerticalDivider(color: AppColors.neutralScale[100], width: 1, thickness: 1),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (w.pop != null)
                      Text('강수확률  ${w.pop}%',
                          style: TextStyle(fontSize: 13, color: AppColors.neutralScale[500])),
                    if (w.pop != null && w.pm10Grade != null)
                      const SizedBox(height: 6),
                    // 등급은 서버가 매긴 값을 그대로 쓴다 — 기준을 양쪽에 두면
                    // 서서히 갈라진다.
                    if (w.pm10Grade != null)
                      Row(
                        children: [
                          Text('미세먼지 ',
                              style: TextStyle(fontSize: 13, color: AppColors.neutralScale[500])),
                          Text(w.pm10Grade!,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                  color: _pmColor(w.pm10Grade!))),
                          if (w.pm25Grade != null) ...[
                            Text(' · 초미세먼지 ',
                                style: TextStyle(fontSize: 13, color: AppColors.neutralScale[500])),
                            Text(w.pm25Grade!,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                    color: _pmColor(w.pm25Grade!))),
                          ],
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(w.attribution,
              style: TextStyle(fontSize: 11, color: AppColors.neutralScale[200])),
        ],
      ),
    );
  }

  Color _pmColor(String label) {
    switch (label) {
      case '좋음': return const Color(0xFF34C759);
      case '보통': return AppColors.blueScale[500]!;
      case '나쁨': return AppColors.redScale[400]!;
      default: return AppColors.redScale[500]!;
    }
  }
}

class _ClothingItem extends StatelessWidget {
  final String label;

  const _ClothingItem({required this.label});

  String get _emoji {
    const shirts = ['반팔', '긴팔', '맨투맨', '기모 티', '티'];
    const pants = ['반바지', '긴바지', '청바지', '기모 바', '하의'];
    if (shirts.any(label.contains)) return '👕';
    if (pants.any(label.contains)) return '👖';
    if (label.contains('샌들')) return '👡';
    return '🧥';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(_emoji, style: const TextStyle(fontSize: 48)),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(fontSize: 12, color: AppColors.neutralScale[400])),
      ],
    );
  }
}
