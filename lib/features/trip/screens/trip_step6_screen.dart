import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../common/theme/app_colors.dart';
import '../../../core/state/trip_repository.dart';

class TripStep6Screen extends StatefulWidget {
  const TripStep6Screen({super.key, this.showBackButton = false});

  final bool showBackButton;

  @override
  State<TripStep6Screen> createState() => _TripStep6ScreenState();
}

class _TripStep6ScreenState extends State<TripStep6Screen> {
  late bool _isSaved = widget.showBackButton; // 저장 탭에서 열면 버튼 숨김

  // 샘플 일정 데이터
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
        label: '이동: 전동 킥보드',
        duration: '13분',
        distance: '2.1km',
      ),
    ),
    _ScheduleStop(
      name: '속초 중앙시장',
      address: '강원특별자치도 속초시 중앙로 147번길',
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
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: AppColors.neutralScale[500],
                  ),
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
        // ── 스크롤 가능한 일정 목록 ──
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMapArea(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitle(),
                      const SizedBox(height: 16),
                      _buildTotalTime(),
                      const SizedBox(height: 20),
                      ..._stops.asMap().entries.map((entry) {
                        return _buildStopItem(
                          entry.value,
                          entry.key == _stops.length - 1,
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── 저장 후 재탐색 버튼 ──
        if (_isSaved && !widget.showBackButton)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextButton(
                  onPressed: () => context.go('/trip/search'),
                  child: Text(
                    '재탐색하기',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.neutralScale[400],
                    ),
                  ),
                ),
              ),
            ),
          ),
        // ── 하단 고정 버튼 (저장 전에만 표시) ──
        if (!_isSaved)
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSaveButton(context),
                const SizedBox(height: 12),
                _buildExploreMoreButton(context),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMapArea() {
    return Container(
      width: double.infinity,
      height: 280,
      color: const Color(0xFFD0E8F0),
      child: Stack(
        children: [
          // 카카오맵 SDK 영역 (추후 KakaoMap 위젯으로 교체)
          Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color(0xFFD0E8F0),
            child: Center(
              child: Icon(
                Icons.map_outlined,
                size: 48,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
          // 경로 번호 마커 (샘플)
          Positioned(
            left: 80,
            top: 80,
            child: _buildNumberMarker('3'),
          ),
          Positioned(
            right: 100,
            bottom: 80,
            child: _buildNumberMarker('1'),
          ),
          Positioned(
            right: 60,
            bottom: 80,
            child: _buildNumberMarker('2'),
          ),
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
            color: Colors.black.withValues(alpha: 0.15),
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

  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '일정이 완성되었어요!',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.neutralScale[600],
            height: 1.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '일정을 검토하고 경로를 확정해주세요.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.neutralScale[300],
          ),
        ),
      ],
    );
  }

  Widget _buildTotalTime() {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 14,
          color: AppColors.neutralScale[400],
        ),
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

  Widget _buildStopItem(_ScheduleStop stop, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타임라인 (원 + 선)
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryScale[300]!,
                      width: 2,
                    ),
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
                // 장소명 + 시간
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
                // 주소
                Text(
                  stop.address,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.neutralScale[300],
                  ),
                ),
                // 이동 수단 카드
                if (stop.transport != null) ...[
                  const SizedBox(height: 12),
                  _buildTransportCard(stop.transport!),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportCard(_TransportInfo transport) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.neutralScale[0],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutralScale[100]!),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primaryScale[0],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.electric_scooter,
              size: 18,
              color: AppColors.primaryScale[400],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            transport.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.neutralScale[500],
            ),
          ),
          const Spacer(),
          Text(
            '${transport.duration} · ${transport.distance}',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.neutralScale[300],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.gradientScale[200]!,
              AppColors.gradientScale[600]!,
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: ElevatedButton(
          onPressed: () => _showSaveBottomSheet(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: const Text(
            '일정 저장하기',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExploreMoreButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: TextButton(
        onPressed: () => context.go('/trip/search'),
        child: Text(
          '추가 탐색하기',
          style: TextStyle(
            color: AppColors.neutralScale[400],
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

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
              // 메시지
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
              // 버튼 행
              Row(
                children: [
                  // 닫기
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.neutralScale[200]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                  // 보러가기
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.gradientScale[200]!,
                            AppColors.gradientScale[600]!,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          TripRepository.instance.requestedTab.value = 0;
                          // 다이얼로그 닫힌 후 이동
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            context.go('/saved');
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          '보러가기',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
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
          _showSavedDialog(context, name); // 스크린 context 사용
        },
      ),
    );
  }
}

// ─── 저장 바텀시트 ───────────────────────────────────────────

class _SaveBottomSheet extends StatefulWidget {
  const _SaveBottomSheet({required this.onSaved});

  final void Function(String name) onSaved;

  @override
  State<_SaveBottomSheet> createState() => _SaveBottomSheetState();
}

class _SaveBottomSheetState extends State<_SaveBottomSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // 바텀시트 열릴 때 자동 포커스
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
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
      padding: EdgeInsets.fromLTRB(24, 14, 24, keyboardHeight > 0 ? keyboardHeight + 16 : bottomPadding + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 드래그 핸들
          Center(
            child: Container(
              width: 44,
              height: 5,
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
            style: TextStyle(
              fontSize: 14,
              color: AppColors.neutralScale[300],
            ),
          ),
          const SizedBox(height: 40),
          // 텍스트 필드
          _buildNameField(),
          const SizedBox(height: 40),
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
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          maxLength: 20,
          onChanged: (_) => setState(() {}),
          style: TextStyle(
            fontSize: 16,
            color: AppColors.neutralScale[600],
          ),
          decoration: InputDecoration(
            hintText: '일정 이름',
            hintStyle: TextStyle(
              color: AppColors.neutralScale[200],
              fontSize: 16,
            ),
            counterText: '',
            contentPadding: const EdgeInsets.only(bottom: 12),
            // × 버튼: 항상 표시, 텍스트 없으면 연회색
            suffixIcon: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: IconButton(
                icon: Icon(
                  Icons.cancel,
                  size: 20,
                  color: _controller.text.isNotEmpty
                      ? AppColors.neutralScale[300]
                      : AppColors.neutralScale[100],
                ),
                onPressed: _controller.text.isNotEmpty
                    ? () {
                        _controller.clear();
                        setState(() {});
                      }
                    : null,
              ),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: AppColors.neutralScale[100]!,
                width: 1.5,
              ),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: AppColors.primaryScale[500]!,
                width: 2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_controller.text.length} / 20',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.neutralScale[300],
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.gradientScale[200]!,
              AppColors.gradientScale[600]!,
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: ElevatedButton(
          onPressed: () {
            if (_controller.text.isNotEmpty) {
              widget.onSaved(_controller.text);
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            overlayColor: Colors.white.withValues(alpha: 0.15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: const Text(
            '일정 저장하기',
            style: TextStyle(
              color: Colors.white,
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
