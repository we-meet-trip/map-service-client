import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/theme/app_icons.dart';
import '../widgets/transport_theme.dart';
import '../../../common/widgets/next_button.dart';
import '../../../common/widgets/prev_button.dart';
import '../../../core/state/trip_repository.dart';
import '../../../common/widgets/text_field.dart';

class TripCreatedScreen extends StatefulWidget {
  const TripCreatedScreen({
    super.key,
    this.showBackButton = false,
    this.onPrev,
  });

  final bool showBackButton;
  final VoidCallback? onPrev;

  @override
  State<TripCreatedScreen> createState() => _TripCreatedScreenState();
}

class _TripCreatedScreenState extends State<TripCreatedScreen> {
  late bool _isSaved = widget.showBackButton;

  final List<_ScheduleStop> _stops = [
    _ScheduleStop(
      name: '속초 버스 터미널',
      address: '강원특별자치도 속초시 중앙로 96',
      time: '09:00 AM',
      transport: _TransportInfo(
        label: '이동: 전동 킥보드',
        duration: '12분',
        distance: '1.8km',
      ),
    ),
    _ScheduleStop(
      name: '속초해변',
      address: '강원특별자치도 속초시 청호동',
      time: '09:12 AM',
      transport: _TransportInfo(
        label: '이동: 바이크',
        duration: '13분',
        distance: '3.8km',
      ),
    ),
    _ScheduleStop(
      name: '속초 중앙시장',
      address: '강원특별자치도 속초시 중앙로 147',
      time: '09:25 AM',
      transport: null,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── 저장 탭에서 열렸을 때 뒤로가기 헤더 ──
        if (widget.showBackButton)
          Container(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 4),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 20, color: AppColors.neutralScale[500]),
                  onPressed: () => context.go('/saved'),
                ),
                Text(
                  '저장된 일정',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutralScale[500],
                  ),
                ),
              ],
            ),
          ),
        // ── 스크롤 영역 ──
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 지도 영역 (KakaoMap SDK 연결 예정) ──
                _buildMapArea(),
                // ── 일정 내용 ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitle(),
                      const SizedBox(height: 16),
                      _buildTotalTime(),
                      const SizedBox(height: 28),
                      ..._stops.asMap().entries.map((entry) =>
                          _buildStopItem(entry.value, entry.key == _stops.length - 1)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── 하단 고정 버튼 ──
        if (!widget.showBackButton) _buildBottomButtons(context),
      ],
    );
  }

  // ── 지도 플레이스홀더 ────────────────────────────────────────

  Widget _buildMapArea() {
    return Container(
      width: double.infinity,
      height: 280,
      color: const Color(0xFFD0E8F0),
      child: Stack(
        children: [
          // KakaoMap SDK 연결 예정
          Center(
            child: Icon(
              Icons.map_outlined,
              size: 48,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          // 경로 번호 마커
          Positioned(left: 80, top: 80,   child: _buildNumberMarker('3')),
          Positioned(right: 100, bottom: 80, child: _buildNumberMarker('1')),
          Positioned(right: 60,  bottom: 80, child: _buildNumberMarker('2')),
        ],
      ),
    );
  }

  Widget _buildNumberMarker(String number) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.neutralScale[600]!.withAlpha(0x26),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          number,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.neutralScale[600],
          ),
        ),
      ),
    );
  }

  // ── 제목 / 소요시간 ──────────────────────────────────────────

  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '일정이 완성되었어요!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.neutralScale[600],
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '일정을 검토하고 경로를 확정해주세요.',
          style: TextStyle(fontSize: 13, color: AppColors.neutralScale[300]),
        ),
      ],
    );
  }

  Widget _buildTotalTime() {
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 14, color: AppColors.neutralScale[400]),
        children: [
          const TextSpan(text: '총 소요시간 : 약 '),
          TextSpan(
            text: '25분',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primaryScale[500],
            ),
          ),
        ],
      ),
    );
  }

  // ── 일정 아이템 ──────────────────────────────────────────────

  Widget _buildStopItem(_ScheduleStop stop, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타임라인
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryScale[300]!, width: 2),
                    color: Colors.white,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.neutralScale[100],
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 내용
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      stop.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.neutralScale[600],
                      ),
                    ),
                    Text(
                      stop.time,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryScale[500],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  stop.address,
                  style: TextStyle(fontSize: 12, color: AppColors.neutralScale[300]),
                ),
                if (stop.transport != null) ...[
                  const SizedBox(height: 14),
                  _buildTransportCard(stop.transport!),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 이동수단 카드 (글라스 효과 + TransportTheme 색상) ──────────

  Widget _buildTransportCard(_TransportInfo transport) {
    final theme = TransportTheme.byLabel(transport.label);
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        // Refraction: 35 → 강한 배경 블러
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            // Frost: 0 → 투명한 맑은 유리
            // Light: -33°, 80% → 좌상단(밝음) → 우하단(어두움) 그라디언트
            gradient: LinearGradient(
              begin: const Alignment(-0.54, -0.84),
              end:   const Alignment( 0.54,  0.84),
              colors: [
                Colors.white.withValues(alpha: 0.26),
                Colors.white.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.65),
              width: 1.0,
            ),
            boxShadow: [
              // Depth: 7.24 → 외부 그림자
              BoxShadow(
                color: theme.iconColor.withValues(alpha: 0.10),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // 아이콘 원형
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.iconBg,
                ),
                child: Center(
                  child: AppIcon(theme.svgPath, size: 18, color: theme.iconColor),
                ),
              ),
              const SizedBox(width: 12),
              // 라벨
              Text(
                transport.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.neutralScale[600],
                ),
              ),
              const Spacer(),
              // 시간 · 거리
              Text(
                '${transport.duration} · ${transport.distance}',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.neutralScale[400],
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  // ── 하단 버튼 ────────────────────────────────────────────────

  Widget _buildBottomButtons(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_isSaved)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
            child: NextButton(
              label: '일정 저장하기',
              onPressed: () => _showSaveBottomSheet(context),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: PrevButton(
            onPressed: () => context.go('/trip/search'),
            label: _isSaved ? '← 재탐색하러 가기' : '추가 탐색하기',
          ),
        ),
      ],
    );
  }

  // ── 저장 완료 다이얼로그 ─────────────────────────────────────

  void _showSavedDialog(BuildContext context, String name) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.neutralScale[600],
                    height: 1.5,
                  ),
                  children: [
                    TextSpan(
                      text: '"$name"',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryScale[500],
                      ),
                    ),
                    const TextSpan(
                      text: '\n일정이 저장되었어요!',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.neutralScale[200]!),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        '닫기',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutralScale[400],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          AppColors.gradientScale[200]!,
                          AppColors.gradientScale[600]!,
                        ]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          TripRepository.instance.requestedTab.value = 0;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (context.mounted) {
                              context.go('/saved');
                            }
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          '보러가기',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 저장 바텀시트 ─────────────────────────────────────────────

  void _showSaveBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (sheetContext) => _SaveBottomSheet(
        onSaved: (name) {
          TripRepository.instance.addTrip(SavedTrip(
            name: name,
            route: '속초 버스 터미널 → 속초해변 → 속초 중앙시장',
            savedAt: DateTime.now(),
          ));
          setState(() => _isSaved = true);
          _showSavedDialog(context, name);
        },
      ),
    );
  }
}

// ─── 저장 바텀시트 위젯 ───────────────────────────────────────

class _SaveBottomSheet extends StatefulWidget {
  const _SaveBottomSheet({required this.onSaved});
  final void Function(String name) onSaved;

  @override
  State<_SaveBottomSheet> createState() => _SaveBottomSheetState();
}

class _SaveBottomSheetState extends State<_SaveBottomSheet> {
  final _controller = TextEditingController();
  String? _errorText;

  void _onChanged(String value) {
    setState(() {
      if (value.isEmpty) {
        _errorText = null;
      } else if (value.length > 20) {
        _errorText = '20자 이하로 입력해주세요.';
      } else {
        _errorText = null;
      }
    });
  }

  bool get _canSave =>
      _controller.text.isNotEmpty &&
      _controller.text.length <= 20 &&
      _errorText == null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 14, 24,
        keyboardHeight > 0 ? keyboardHeight + 16 : bottomPadding + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 드래그 핸들
          Center(
            child: Container(
              width: 44, height: 5,
              decoration: BoxDecoration(
                color: AppColors.neutralScale[200],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 28),
          // 제목
          Text(
            '✏️ 일정 이름을 정해주세요.',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.neutralScale[600],
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '지정된 여행 목록에 표시될 이름이에요!',
            style: TextStyle(fontSize: 14, color: AppColors.neutralScale[300]),
          ),
          const SizedBox(height: 32),
          // 입력 필드
          _buildNameField(),
          const SizedBox(height: 32),
          // 저장 버튼
          _buildSaveButton(context),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AppTextField(
          controller: _controller,
          hintText: '일정 이름',
          onChanged: _onChanged,
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              height: 16,
              child: _errorText != null
                  ? Text(
                      _errorText!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.error,
                      ),
                    )
                  : null,
            ),
            Text(
              '${_controller.text.length} / 20',
              style: TextStyle(fontSize: 12, color: AppColors.neutralScale[300]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    final bool canSave = _canSave;
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: canSave
                ? [AppColors.secondaryScale[900]!, AppColors.secondaryScale[500]!]
                : [AppColors.neutralScale[100]!, AppColors.neutralScale[100]!],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: ElevatedButton(
          onPressed: canSave
              ? () {
                  Navigator.pop(context);
                  widget.onSaved(_controller.text);
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            overlayColor: Colors.white.withValues(alpha: 0.15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: Text(
            '일정 저장하기',
            style: TextStyle(
              color: canSave ? Colors.white : AppColors.neutralScale[300],
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 데이터 모델 ──────────────────────────────────────────────

class _ScheduleStop {
  final String name;
  final String address;
  final String time;
  final _TransportInfo? transport;

  const _ScheduleStop({
    required this.name,
    required this.address,
    required this.time,
    required this.transport,
  });
}

class _TransportInfo {
  final String label;
  final String duration;
  final String distance;

  const _TransportInfo({
    required this.label,
    required this.duration,
    required this.distance,
  });
}
