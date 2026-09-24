import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../common/constants/korea_regions.dart';
import '../../../common/constants/random_missions.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/next_button.dart';
import '../../../common/widgets/prev_button.dart';
import '../widgets/roulette_wheel.dart';
import '../widgets/trip_card.dart';
import '../widgets/trip_step_header.dart';
import 'plan_flow_screen.dart';

/// 한 단계에서 다시 돌릴 수 있는 횟수. '처음부터'는 제한하지 않는다.
const kRandomRerolls = 2;

/// 뽑을 수 있는 미션. 섬 지역은 대상이 있는지 장담할 수 없어 어디서나 되는
/// 미션만 남긴다.
List<RandomMission> missionsFor(String city) => kIslandCities.contains(city)
    ? kRandomMissions.where((m) => m.universal || m.query == null).toList()
    : kRandomMissions;

/// '랜덤으로 가기' — 돌림판으로 시도와 시군구를 뽑고 미션을 준다.
///
/// AI 를 부르지 않는다. 미션 장소는 '여행 일정 계획하기' 흐름에 지역과 검색어를
/// 미리 채워 찾는다.
class RandomTripScreen extends StatefulWidget {
  const RandomTripScreen({super.key, this.random});

  /// 시험에서 결과를 고정하려고 넣는다. 돈이나 상품이 걸린 추첨이 아니라
  /// 보안용 난수까지는 필요 없다.
  final math.Random? random;

  @override
  State<RandomTripScreen> createState() => _RandomTripScreenState();
}

enum _Stage { province, city, mission }

class _RandomTripScreenState extends State<RandomTripScreen> {
  late final math.Random _random = widget.random ?? math.Random();

  _Stage _stage = _Stage.province;
  RouletteSpin? _spin;
  bool _spinning = false;
  int? _settled;

  String? _province;
  String? _city;
  RandomMission? _mission;

  /// 단계마다 남은 다시 돌리기 횟수.
  final Map<_Stage, int> _rerollsLeft = {
    for (final s in _Stage.values) s: kRandomRerolls,
  };

  List<String> get _cities => kCitiesByProvince[_province] ?? const [];

  List<String> get _labels => switch (_stage) {
    _Stage.province => [for (final p in kProvinces) kProvinceShortNames[p]!],
    _Stage.city => _cities,
    _Stage.mission => const [],
  };

  /// 세종처럼 시군구가 하나뿐이면 두 번째 돌림판을 건너뛰어 단계가 하나 준다.
  int get _stepCount => _province != null && _cities.length == 1 ? 2 : 3;

  int get _stepNumber => switch (_stage) {
    _Stage.province => 1,
    _Stage.city => 2,
    _Stage.mission => _stepCount,
  };

  void _spinWheel() {
    if (_spinning) return;
    final count = _labels.length;
    // 결과를 먼저 뽑고 그 칸에 멈추게 돌린다. 칸이 모두 같은 크기라 화면에
    // 보이는 확률과 실제 확률이 같다.
    final index = _random.nextInt(count);
    final jitter = (_random.nextDouble() * 2 - 1) * 0.35;
    setState(() {
      if (_settled != null) {
        _rerollsLeft[_stage] = _rerollsLeft[_stage]! - 1;
      }
      _settled = null;
      _spinning = true;
      _spin = RouletteSpin(index, jitter: jitter);
    });
  }

  void _onSettled(int index) {
    if (!mounted) return;
    HapticFeedback.selectionClick();
    setState(() {
      _spinning = false;
      _settled = index;
    });
  }

  void _confirm() {
    final index = _settled;
    if (index == null) return;
    setState(() {
      if (_stage == _Stage.province) {
        _province = kProvinces[index];
        final cities = _cities;
        // 시군구가 하나뿐인 곳(세종)은 두 번째 돌림판이 의미가 없다.
        if (cities.length == 1) {
          _city = cities.first;
          _stage = _Stage.mission;
          _drawMission(countAsReroll: false);
        } else {
          _stage = _Stage.city;
        }
      } else if (_stage == _Stage.city) {
        _city = _cities[index];
        _stage = _Stage.mission;
        _drawMission(countAsReroll: false);
      }
      _spin = null;
      _settled = null;
    });
  }

  void _drawMission({bool countAsReroll = true}) {
    final pool = missionsFor(_city!);
    var next = pool[_random.nextInt(pool.length)];
    // 다시 뽑았는데 같은 미션이 나오면 뽑은 느낌이 없다.
    if (pool.length > 1) {
      while (next.id == _mission?.id) {
        next = pool[_random.nextInt(pool.length)];
      }
    }
    if (countAsReroll) {
      _rerollsLeft[_Stage.mission] = _rerollsLeft[_Stage.mission]! - 1;
    }
    _mission = next;
  }

  void _restart() {
    setState(() {
      _stage = _Stage.province;
      _spin = null;
      _spinning = false;
      _settled = null;
      _province = null;
      _city = null;
      _mission = null;
      for (final s in _Stage.values) {
        _rerollsLeft[s] = kRandomRerolls;
      }
    });
  }

  void _goFindPlace() {
    final mission = _mission!;
    context.go(
      '/trip/plan',
      extra: PlanPreset(
        province: _province!,
        city: _city!,
        query: mission.query,
        headline: mission.title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    // 앞 화면의 어두운 배경이 상태바를 흰 글자로 바꿔 두므로 되돌린다.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              // 아래 버튼 그림자가 내용과 겹치지 않게 여유를 둔다.
              padding: EdgeInsets.fromLTRB(24, topPad + 24, 24, 48),
              children: [
                TripStepHeader(
                  step: _stepNumber,
                  totalSteps: _stepCount,
                  isNextEnabled: _stage == _Stage.mission || _settled != null,
                  title: switch (_stage) {
                    _Stage.province => '어느 지역으로 떠날까요?',
                    _Stage.city => '$_province 어디로 갈까요?',
                    _Stage.mission => '이번 여행의 미션',
                  },
                  subtitle: _stage == _Stage.mission
                      ? '${regionLabel(_province!, _city)}에서 해 볼 일이에요.'
                      : '돌림판을 돌려 여행지를 정해요.',
                ),
                const SizedBox(height: 28),
                if (_stage == _Stage.mission)
                  _buildMissionCard()
                else
                  TripCard(
                    child: Column(
                      children: [
                        // 결과는 돌림판 위에 둔다. 아래에 두면 작은 화면에서 스크롤해야 보인다.
                        _buildResultText(),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) => RouletteWheel(
                            key: ValueKey(_stage),
                            labels: _labels,
                            spin: _spin,
                            onSettled: _onSettled,
                            // 버튼 위에서 카드가 잘리지 않게 화면 높이에도 맞춘다.
                            size: [
                              280.0,
                              constraints.maxWidth,
                              MediaQuery.sizeOf(context).height * 0.27,
                            ].reduce(math.min),
                          ),
                        ),
                        if (_settled != null) ...[
                          const SizedBox(height: 16),
                          _RerollChip(
                            label: '다시 돌리기 (${_rerollsLeft[_stage]}번 남음)',
                            onPressed: _rerollsLeft[_stage]! > 0
                                ? _spinWheel
                                : null,
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 10 + bottomPad),
            child: _buildPrimaryButton(),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _stage == _Stage.province && _settled == null
                ? PrevButton(onPressed: () => context.go('/trip'))
                : PrevButton(onPressed: _restart, label: '처음부터'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultText() {
    final index = _settled;
    final text = index == null
        ? (_spinning ? '돌아가는 중…' : '')
        : '${_labels[index]} 당첨!';
    // 화면 읽기에서 결과가 나오면 바로 읽어 준다.
    return Semantics(
      liveRegion: true,
      child: Text(
        text,
        textAlign: TextAlign.center,
        strutStyle: const StrutStyle(fontSize: 20, forceStrutHeight: true),
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.secondaryScale[900],
        ),
      ),
    );
  }

  Widget _buildPrimaryButton() {
    if (_stage == _Stage.mission) {
      final mission = _mission!;
      return NextButton(
        onPressed: _goFindPlace,
        label: mission.query == null ? '일정 짜러 가기  →' : '미션 장소 찾으러 가기  →',
      );
    }
    if (_settled == null) {
      return NextButton(onPressed: _spinning ? null : _spinWheel, label: '돌리기');
    }
    return NextButton(onPressed: _confirm, label: '이곳으로 할게요  →');
  }

  Widget _buildMissionCard() {
    final mission = _mission!;
    final left = _rerollsLeft[_Stage.mission]!;
    return TripCard(
      child: Column(
        children: [
          Semantics(
            liveRegion: true,
            child: Column(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.secondaryScale[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.flag_rounded,
                    size: 24,
                    color: AppColors.secondaryScale[500],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  mission.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutralScale[600],
                    height: 1.35,
                  ),
                ),
                if (kIslandCities.contains(_city)) ...[
                  const SizedBox(height: 12),
                  Text(
                    '배편으로 가는 지역이에요. 운항 여부를 먼저 확인해 주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.neutralScale[400],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          _RerollChip(
            label: '미션 다시 뽑기 ($left번 남음)',
            onPressed: left > 0 ? () => setState(() => _drawMission()) : null,
          ),
        ],
      ),
    );
  }
}

/// 다시 돌리기·다시 뽑기용 알약 버튼. 장소 시트의 '후기 더보기'와 같은 모양이다.
class _RerollChip extends StatelessWidget {
  const _RerollChip({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final fg = enabled
        ? AppColors.tripAccentPurple
        : AppColors.neutralScale[400]!;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: enabled
            ? AppColors.reviewMoreButtonBg
            : AppColors.neutralScale[100],
        shape: StadiumBorder(
          side: BorderSide(
            color: enabled
                ? AppColors.tripOriginChipBorder
                : Colors.transparent,
          ),
        ),
        child: InkWell(
          onTap: onPressed,
          customBorder: const StadiumBorder(),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded, size: 16, color: fg),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
