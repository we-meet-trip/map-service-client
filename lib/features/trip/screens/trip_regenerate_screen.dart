import 'package:flutter/material.dart';
import '../../../common/widgets/app_loading_screen.dart';
import '../../../core/api/trip_api_service.dart';
import '../../../core/state/trip_repository.dart';
import 'trip_start_screen.dart';
import 'trip_step1_screen.dart';
import 'trip_step2_screen.dart';
import 'trip_step3_screen.dart';
import 'trip_step4_screen.dart';
import 'trip_step5_screen.dart';
import 'trip_created_screen.dart';

/// 바텀 탭 재탭 시 시작 화면(step 0)으로 이동
final tripScreenResetNotifier = ValueNotifier<int>(0);

/// 재탐색 시작하기 시 step 1로 이동 + 전체 리셋
final tripRetrialNotifier = ValueNotifier<int>(0);

class TripRegenerateScreen extends StatefulWidget {
  const TripRegenerateScreen({super.key});

  @override
  State<TripRegenerateScreen> createState() => _TripRegenerateScreenState();
}

//API 사용시 false로 변경하면 됩니다.
const bool _useMock = true;

Future<TripGenerateResponse> _mockGenerateTrip() async {
  await Future.delayed(const Duration(seconds: 2));
  return const TripGenerateResponse(
    tripId: 'mock-trip-001',
    totalDurationMinutes: 180,
    stops: [
      TripStop(
        order: 1,
        name: '속초 버스 터미널',
        address: '강원특별자치도 속초시 중앙로 96',
        time: '09:00',
        latitude: 38.2052,
        longitude: 128.5917,
        transportToNext: TripTransportToNext(
          type: 'kick_board',
          label: '이동: 전동 킥보드',
          durationMinutes: 12,
          distanceKm: 1.8,
        ),
      ),
      TripStop(
        order: 2,
        name: '속초해변',
        address: '강원특별자치도 속초시 청호동',
        time: '09:12',
        latitude: 38.2014,
        longitude: 128.6008,
        transportToNext: TripTransportToNext(
          type: 'bicycle',
          label: '이동: 자전거',
          durationMinutes: 13,
          distanceKm: 3.8,
        ),
      ),
      TripStop(
        order: 3,
        name: '속초 중앙시장',
        address: '강원특별자치도 속초시 중앙로 147',
        time: '09:25',
        latitude: 38.2089,
        longitude: 128.5875,
      ),
    ],
    weatherForecast: [],
  );
}

class _TripRegenerateScreenState extends State<TripRegenerateScreen> {
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    tripScreenResetNotifier.addListener(_onTabReset);
    tripRetrialNotifier.addListener(_onRetrial);
    // 로그인/회원가입 후 복귀 시 임시 저장된 일정 복원
    final pending = TripRepository.instance.pendingTrip;
    if (pending != null) {
      _tripResponse = pending;
      _currentStep = 6;
      TripRepository.instance.pendingTrip = null;
    }
  }

  @override
  void dispose() {
    tripScreenResetNotifier.removeListener(_onTabReset);
    tripRetrialNotifier.removeListener(_onRetrial);
    super.dispose();
  }

  /// 바텀 탭 탭: 시작 화면으로 (기존 입력값 유지)
  void _onTabReset() {
    if (!mounted) return;
    setState(() => _currentStep = 0);
  }

  /// 재탐색: step 1로 + 전체 리셋
  void _onRetrial() {
    if (!mounted) return;
    setState(() {
      _currentStep = 1;
      _startDate = null;
      _endDate = null;
      _startHour = 0;
      _endHour = 0;
      _minBudget = 0;
      _maxBudget = 0;
      _selectedThemes = {};
      _selectedTransport = null;
      _selectedProvince = '선택';
      _selectedCity = '선택';
      _tripResponse = null;
      _generateFuture = null;
    });
  }

  static const int _totalSteps = 6;

  // Step 1
  DateTime? _startDate;
  DateTime? _endDate;
  double _startHour = 0;
  double _endHour = 0;

  // Step 2
  double _minBudget = 0;
  double _maxBudget = 0;

  // Step 3
  Set<String> _selectedThemes = {};

  // Step 4
  String? _selectedTransport;

  // Step 5
  String _selectedProvince = '선택';
  String _selectedCity = '선택';

  bool _isLoading = false;
  Future<void>? _generateFuture;
  TripGenerateResponse? _tripResponse;

  void _next() {
    if (_currentStep == 5) {
      // step 5 → 로딩 + API 호출
      final request = TripGenerateRequest(
        startDate: _startDate!,
        endDate: _endDate!,
        activeStartHour: _startHour.toInt(),
        activeEndHour: _endHour.toInt(),
        minBudget: _minBudget.toInt(),
        maxBudget: _maxBudget.toInt(),
        themes: _selectedThemes.toList(),
        transport: _selectedTransport!,
        province: _selectedProvince,
        city: _selectedCity,
      );
      setState(() {
        _isLoading = true;
        _generateFuture = (_useMock
                ? _mockGenerateTrip()
                : TripApiService.instance.generateTrip(request))
            .then((res) => _tripResponse = res);
      });
    } else if (_currentStep < _totalSteps) {
      setState(() => _currentStep++);
    }
  }

  void _prev() {
    if (_currentStep > 1) setState(() => _currentStep--);
  }

  void _onLoadComplete() {
    setState(() {
      _isLoading = false;
      _generateFuture = null;
      _currentStep = 6;
    });
  }

  void _onLoadError(Object error) {
    final msg = error is TripApiException
        ? error.message
        : '일정 생성에 실패했습니다. 다시 시도해 주세요.';
    setState(() {
      _isLoading = false;
      _generateFuture = null;
      _currentStep = 5;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return AppLoadingScreen(
        future: _generateFuture,
        minDuration: const Duration(seconds: 2),
        onComplete: _onLoadComplete,
        onError: _onLoadError,
      );
    }

    switch (_currentStep) {
      case 0:
        return TripStartScreen(onStart: _next);
      case 1:
        return TripStep1Screen(
          onNext: _next,
          startDate: _startDate,
          endDate: _endDate,
          startHour: _startHour,
          endHour: _endHour,
          onDateChanged: (s, e) => setState(() {
            _startDate = s;
            _endDate = e;
          }),
          onTimeChanged: (s, e) => setState(() {
            _startHour = s;
            _endHour = e;
          }),
        );
      case 2:
        return TripStep2Screen(
          onNext: _next,
          onPrev: _prev,
          minBudget: _minBudget,
          maxBudget: _maxBudget,
          onBudgetChanged: (min, max) => setState(() {
            _minBudget = min;
            _maxBudget = max;
          }),
        );
      case 3:
        return TripStep3Screen(
          onNext: _next,
          onPrev: _prev,
          selectedThemes: _selectedThemes,
          onThemesChanged: (t) => setState(() {
            _selectedThemes = t;
          }),
        );
      case 4:
        return TripStep4Screen(
          onNext: _next,
          onPrev: _prev,
          selectedTransport: _selectedTransport,
          onTransportChanged: (t) => setState(() => _selectedTransport = t),
        );
      case 5:
        return TripStep5Screen(
          onNext: _next,
          onPrev: _prev,
          selectedProvince: _selectedProvince,
          selectedCity: _selectedCity,
          onLocationChanged: (p, c) => setState(() {
            _selectedProvince = p;
            _selectedCity = c;
          }),
        );
      case 6:
        return TripCreatedScreen(response: _tripResponse);
      default:
        return const SizedBox.shrink();
    }
  }
}
