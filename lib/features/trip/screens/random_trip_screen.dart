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
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(24, topPad + 24, 24, 24),
            children: [
              Text(
                switch (_stage) {
                  _Stage.province => '어느 지역으로 떠날까요?',
                  _Stage.city => '$_province 어디로 갈까요?',
                  _Stage.mission => '이번 여행의 미션',
                },
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.neutralScale[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _stage == _Stage.mission
                    ? '$_province $_city에서 해 볼 일이에요.'
                    : '돌림판을 돌려 여행지를 정해요.',
                style: TextStyle(fontSize: 13, color: AppColors.neutralScale[400]),
              ),
              const SizedBox(height: 24),
              if (_stage == _Stage.mission)
                _buildMissionCard()
              else ...[
                // 결과는 돌림판 위에 둔다. 아래에 두면 작은 화면에서 스크롤해야 보인다.
                _buildResultText(),
                const SizedBox(height: 12),
                Center(
                  child: RouletteWheel(
                    key: ValueKey(_stage),
                    labels: _labels,
                    spin: _spin,
                    onSettled: _onSettled,
                  ),
                ),
              ],
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
          color: AppColors.secondaryScale[500],
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
    final left = _rerollsLeft[_stage]!;
    if (_settled == null) {
      return NextButton(
        onPressed: _spinning ? null : _spinWheel,
        label: '돌리기',
      );
    }
    return Column(
      children: [
        NextButton(onPressed: _confirm, label: '이곳으로 할게요  →'),
        TextButton(
          onPressed: left > 0 ? _spinWheel : null,
          child: Text('다시 돌리기 ($left번 남음)'),
        ),
      ],
    );
  }

  Widget _buildMissionCard() {
    final mission = _mission!;
    final left = _rerollsLeft[_Stage.mission]!;
    return Column(
      children: [
        Semantics(
          liveRegion: true,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.secondaryScale[0],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.secondaryScale[200]!),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.flag_rounded,
                  size: 36,
                  color: AppColors.secondaryScale[500],
                ),
                const SizedBox(height: 12),
                Text(
                  mission.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutralScale[700],
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
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: left > 0
              ? () => setState(() => _drawMission())
              : null,
          child: Text('미션 다시 뽑기 ($left번 남음)'),
        ),
      ],
    );
  }
}
