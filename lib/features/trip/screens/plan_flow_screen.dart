import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/places_api_service.dart';
import '../../../core/api/trip_api_service.dart';
import '../../../core/state/trip_repository.dart';
import '../widgets/transport_theme.dart';
import '../utils/plan_edit_draft.dart';
import 'manual_plan_screen.dart';
import 'plan_map_screen.dart';
import 'trip_created_screen.dart';
import 'trip_step1_screen.dart';
import 'trip_step5_screen.dart';

/// '여행 일정 계획하기' — AI 없이 직접 장소를 찾아 일정을 짠다.
///
/// 날짜 → 지역 → 지도에서 장소 담기 → 동선 → 결과. 동선은 서버가 계산하지만
/// 장소를 고르는 데 AI 를 쓰지 않으므로 외부 AI 동의가 필요 없다.
class PlanFlowScreen extends StatefulWidget {
  const PlanFlowScreen({super.key});

  @override
  State<PlanFlowScreen> createState() => _PlanFlowScreenState();
}

enum _Step { dates, region, map, route, result }

class _PlanFlowScreenState extends State<PlanFlowScreen> {
  late _Step _step = _Step.dates;

  DateTime? _startDate;
  DateTime? _endDate;
  double _startHour = 0;
  double _endHour = 0;
  String _province = '선택';
  String _city = '선택';
  List<PlaceSearchItem> _picked = const [];

  /// 동선 화면에서 고친 장소·이동수단. 결과를 남길 때 고친 이동수단을 쓴다.
  PlanEditDraft? _draft;
  TripGenerateResponse? _result;

  static const _totalSteps = 3;

  /// 시도 전체를 고르면 시군구가 '전체'로 온다. 검색·동선에는 시군구 없이 보낸다.
  String? get _cityOrNull => _city == '전체' || _city == '선택' ? null : _city;

  @override
  void initState() {
    super.initState();
    // 결과 화면의 '새 일정 만들기'는 여행 계획 탭의 첫 화면으로 돌아가라는 뜻이다.
    TripRepository.instance.newPlanRequested.addListener(_leave);
  }

  @override
  void dispose() {
    TripRepository.instance.newPlanRequested.removeListener(_leave);
    super.dispose();
  }

  void _leave() {
    if (mounted) context.go('/trip');
  }

  void _go(_Step step) => setState(() => _step = step);

  /// 담은 장소를 여행 일수에 고르게 나눠 넣는다. 어느 날에 둘지는 다음
  /// 화면에서 옮길 수 있다.
  List<TripStop> _initialStops() {
    final days = _endDate!.difference(_startDate!).inDays.abs() + 1;
    final n = _picked.length;
    return [
      for (var i = 0; i < n; i++)
        tripStopFromSearchItem(
          _picked[i],
          order: i + 1,
          day: i * days ~/ n + 1,
        ),
    ];
  }

  void _onRouted(TripGenerateResponse response) {
    // 저장·재탐색이 이 일정을 출발점으로 삼는다. 추천 마법사와 같은 자리에 남긴다.
    TripRepository.instance.setLastPlan(
      TripPlanContext(
        startDate: _startDate!,
        endDate: _endDate!,
        activeStartHour: _startHour.toInt(),
        activeEndHour: _endHour.toInt(),
        transport: _draft!.transport,
        province: _province,
        city: _city,
        stops: response.stops,
        tripId: response.tripId,
      ),
    );
    setState(() {
      _result = response;
      _step = _Step.result;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 앞 화면의 어두운 배경이 상태바를 흰 글자로 바꿔 두므로 되돌린다.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: _buildStep(context),
    );
  }

  Widget _buildStep(BuildContext context) {
    return switch (_step) {
      _Step.dates => TripStep1Screen(
        step: 1,
        totalSteps: _totalSteps,
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
        onPrev: () => context.go('/trip'),
        onNext: () => _go(_Step.region),
      ),
      _Step.region => TripStep5Screen(
        step: 2,
        totalSteps: _totalSteps,
        selectedProvince: _province,
        selectedCity: _city,
        onLocationChanged: (p, c) => setState(() {
          _province = p;
          _city = c;
        }),
        onPrev: () => _go(_Step.dates),
        onNext: () => _go(_Step.map),
      ),
      _Step.map => PlanMapScreen(
        province: _province,
        city: _cityOrNull,
        step: 3,
        totalSteps: _totalSteps,
        initialSelection: _picked,
        onPrev: () => _go(_Step.region),
        onNext: (selected) {
          _picked = selected;
          _draft = PlanEditDraft(
            stops: _initialStops(),
            transport: _draft?.transport ?? TransportTheme.walk.id,
          );
          _go(_Step.route);
        },
      ),
      _Step.route => ManualPlanScreen(
        draft: _draft,
        initialStops: _draft!.stops,
        startDate: _startDate!,
        endDate: _endDate!,
        activeStartHour: _startHour.toInt(),
        activeEndHour: _endHour.toInt(),
        transport: _draft!.transport,
        province: _province,
        city: _city,
        entry: 'plan_start',
        title: '동선 짜기',
        subtitle:
            '담은 장소의 날짜와 순서를 정해요.\n'
            '방문 시각과 이동 시간은 동선을 만들 때 계산돼요.',
        onRouted: _onRouted,
        onCancel: () => _go(_Step.map),
      ),
      _Step.result => TripCreatedScreen(
        response: _result,
        startDate: _startDate,
        endDate: _endDate,
        showAiSummary: false,
      ),
    };
  }
}
