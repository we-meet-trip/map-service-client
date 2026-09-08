import 'package:flutter/material.dart';
import '../../../common/widgets/app_loading_screen.dart';
import '../../../core/api/trip_api_service.dart';
import '../../../core/state/auth_store.dart';
import '../../../common/widgets/external_ai_consent.dart';
import '../../../core/state/trip_repository.dart';
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
  const TripRegenerateScreen({super.key, this.api, this.consentGate});
  final TripApiService? api;
  final ExternalAiConsentGate? consentGate;

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
  bool _askingConsent = false;
  ExternalAiPermission? _permission;
  final _screenSession = AuthStore.instance.sessionVersion;
  bool get _canSend =>
      mounted &&
      _screenSession == AuthStore.instance.sessionVersion &&
      _permission?.isCurrentSession == true;
  Future<void>? _generateFuture;
  TripGenerateResponse? _tripResponse;

  Future<void> _next() async {
    if (_isLoading || _askingConsent) return;
    if (_currentStep == 5) {
      // step 5 → 로딩 + API 호출
      final request = TripGenerateRequest(
        startDate: _startDate!,
        endDate: _endDate!,
        activeStartHour: _startHour.toInt(),
        activeEndHour: _endHour.toInt(),
        minBudget: _minBudget.toInt(),
        maxBudget: _maxBudget.toInt(),
        themes: _selectedThemes.isEmpty
            ? [_kDefaultThemeId]
            : _selectedThemes.toList(),
        transport: _selectedTransport ?? TransportTheme.scooter.id,
        province: _selectedProvince,
        city: _selectedCity,
      );
      if (_screenSession != AuthStore.instance.sessionVersion) return;
      setState(() => _askingConsent = true);
      final permission =
          await (widget.consentGate ?? ExternalAiConsentGate.instance).ensure(
            context,
            ExternalAiScope.trip,
          );
      if (!mounted) return;
      setState(() => _askingConsent = false);
      _permission = permission;
      if (permission == null || !_canSend) return;
      setState(() {
        _isLoading = true;
        _generateFuture = (widget.api ?? TripApiService.instance)
            .generateTrip(request, canSend: () => _canSend)
            .then((res) {
              if (!_canSend) {
                throw const TripApiException(
                  error: 'SESSION_CHANGED',
                  message: '로그인 상태가 바뀌었어요.',
                  statusCode: 409,
                );
              }
              _tripResponse = res;
              // 장소를 골라 동선만 다시 만들 때 이 조건을 그대로 다시 보낸다.
              // 결과 화면에는 장소만 있고 기간·이동수단·지역이 없어 여기서 남긴다.
              TripRepository.instance.setLastPlan(
                TripPlanContext(
                  startDate: request.startDate,
                  endDate: request.endDate,
                  activeStartHour: request.activeStartHour,
                  activeEndHour: request.activeEndHour,
                  transport: request.transport,
                  province: request.province,
                  city: request.city,
                  stops: res.stops,
                  // 재탐색은 같은 조건으로 다시 묻는 흐름이라 예산·테마와 이 일정의
                  // 식별자까지 남겨 둔다. 없으면 마법사를 처음부터 다시 태워야 한다.
                  tripId: res.tripId,
                  minBudget: request.minBudget,
                  maxBudget: request.maxBudget,
                  themes: request.themes,
                ),
              );
            });
        _generateFuture!.ignore();
      });
    } else if (_currentStep < _totalSteps) {
      setState(() => _currentStep++);
    }
  }

  void _prev() {
    if (_currentStep > 1) setState(() => _currentStep--);
  }

  void _onLoadComplete() {
    if (!_canSend) {
      _onLoadError(
        const TripApiException(
          error: 'SESSION_CHANGED',
          message: '로그인 상태가 바뀌었어요.',
          statusCode: 409,
        ),
      );
      return;
    }
    setState(() {
      _isLoading = false;
      _generateFuture = null;
      _currentStep = 6;
    });
  }

  void _onLoadError(Object error) {
    if (!mounted) return;
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
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
