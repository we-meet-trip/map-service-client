import 'package:flutter/material.dart';
import '../../../common/widgets/app_loading_screen.dart';
import '../../../core/api/trip_api_service.dart';
import '../widgets/transport_theme.dart';
import 'trip_start_screen.dart';
import 'trip_step1_screen.dart';
import 'trip_step2_screen.dart';
import 'trip_step3_screen.dart';
import 'trip_step4_screen.dart';
import 'trip_step5_screen.dart';
import 'trip_created_screen.dart';

// trip_step3_screen.dart 테마 목록의 첫 항목(맛집 탐방) id와 동일해야 한다.
const _kDefaultThemeId = 'food';

/// 바텀 탭 재탭 시 시작 화면(step 0)으로 이동
final tripScreenResetNotifier = ValueNotifier<int>(0);

/// 재탐색 시작하기 시 step 1로 이동 + 전체 리셋
final tripRetrialNotifier = ValueNotifier<int>(0);

class TripRegenerateScreen extends StatefulWidget {
  const TripRegenerateScreen({super.key});

  @override
  State<TripRegenerateScreen> createState() => _TripRegenerateScreenState();
}

class _TripRegenerateScreenState extends State<TripRegenerateScreen> {
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    tripScreenResetNotifier.addListener(_onTabReset);
    tripRetrialNotifier.addListener(_onRetrial);
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
        themes: _selectedThemes.isEmpty ? [_kDefaultThemeId] : _selectedThemes.toList(),
        transport: _selectedTransport ?? TransportTheme.scooter.id,
        province: _selectedProvince,
        city: _selectedCity,
      );
      setState(() {
        _isLoading = true;
        _generateFuture = TripApiService.instance
            .generateTrip(request)
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
        return TripCreatedScreen(
          response: _tripResponse,
          startDate: _startDate,
          endDate: _endDate,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
