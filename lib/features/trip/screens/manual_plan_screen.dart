import 'package:flutter/material.dart';
import '../../../common/theme/app_colors.dart';
import '../../../common/widgets/app_loading_screen.dart';
import '../../../common/widgets/next_button.dart';
import '../../../common/widgets/prev_button.dart';
import '../../../core/api/places_api_service.dart';
import '../../../core/api/trip_api_service.dart';
import '../../../core/state/auth_store.dart';
import '../../../common/widgets/external_ai_consent.dart';
import '../utils/manual_route_request.dart';
import '../utils/plan_edit_draft.dart';
import '../widgets/transport_theme.dart';

/// 직접 장소를 고르고 고쳐서 일정을 짜는 화면.
///
/// 장소를 더하고 빼고 순서를 바꾸는 것까지가 여기서 하는 일이다. 방문 시각과
/// 이동 구간은 손대지 않는다 — 한 자리만 바꿔도 앞뒤가 전부 밀려서, 그 계산은
/// 서버가 통째로 다시 한다("동선 만들기").
///
/// 저장 전 일정과 저장된 일정 모두 이 화면으로 들어온다. 다른 점은 결과를
/// 어디에 쓰느냐뿐이라 [onRouted] 로 넘긴다.
class ManualPlanScreen extends StatefulWidget {
  const ManualPlanScreen({
    super.key,
    required this.initialStops,
    this.draft,
    this.route,
    this.consentGate,
    required this.startDate,
    required this.endDate,
    required this.activeStartHour,
    required this.activeEndHour,
    required this.transport,
    required this.province,
    required this.city,
    required this.onRouted,
    required this.onCancel,
  });

  final List<TripStop> initialStops;
  final PlanEditDraft? draft;
  final Future<TripGenerateResponse> Function(TripRouteRequest)? route;
  final ExternalAiConsentGate? consentGate;
  final DateTime startDate;
  final DateTime endDate;
  final int activeStartHour;
  final int activeEndHour;
  final String transport;
  final String province;
  final String city;

  /// 동선을 새로 만든 결과를 넘긴다. 저장 전이면 결과 화면으로, 저장된
  /// 일정이면 그 일정을 갈아 끼우는 데 쓴다.
  final void Function(TripGenerateResponse response) onRouted;

  /// 고치기를 그만두고 돌아간다.
  final VoidCallback onCancel;

  @override
  State<ManualPlanScreen> createState() => _ManualPlanScreenState();
}

class _ManualPlanScreenState extends State<ManualPlanScreen> {
  late final PlanEditDraft _draft;
  List<TripStop> get _stops => _draft.stops;
  bool _allowPop = false;
  bool _confirmingCancel = false;

  Future<void>? _routeFuture;
  TripGenerateResponse? _result;
  bool _askingConsent = false;
  ExternalAiPermission? _permission;
  final _screenSession = AuthStore.instance.sessionVersion;
  bool get _canSend =>
      mounted &&
      _screenSession == AuthStore.instance.sessionVersion &&
      _permission?.isCurrentSession == true;

  @override
  void initState() {
    super.initState();
    _draft =
        widget.draft ??
        PlanEditDraft(stops: widget.initialStops, transport: widget.transport);
  }

  /// 여행 일수. 장소를 어느 날에 넣을지 고를 때 쓴다.
  int get _dayCount =>
      widget.endDate.difference(widget.startDate).inDays.abs() + 1;

  /// 화면에 보이는 순서 그대로, 일차별로 묶어서 보여 준다.
  List<TripStop> _stopsOf(int day) => [
    for (final s in _stops)
      if (s.day == day) s,
  ];

  void _remove(TripStop stop) {
    setState(() => _stops.remove(stop));
  }

  void _moveToDay(TripStop stop, int day) {
    setState(() => _draft.moveToDay(stop, day));
  }

  void _reorderWithinDay(int day, int oldIndex, int newIndex) {
    setState(() => _draft.reorderWithinDay(day, oldIndex, newIndex));
  }

  Future<void> _cancel() async {
    if (_confirmingCancel) return;
    _confirmingCancel = true;
    try {
      final discard =
          !_draft.isDirty ||
          await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('수정한 내용을 버릴까요?'),
                  content: const Text('저장된 일정은 바뀌지 않아요.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('계속 수정'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('수정 취소'),
                    ),
                  ],
                ),
              ) ==
              true;
      if (!discard || !mounted) return;
      _draft.reset();
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) widget.onCancel();
    } finally {
      _confirmingCancel = false;
    }
  }

  Widget _guardDraft(Widget child) => PopScope(
    canPop: _allowPop || !_draft.isDirty,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _cancel();
    },
    child: child,
  );

  Future<void> _addPlace() async {
    final picked = await showModalBottomSheet<PlaceSearchItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _PlaceSearchSheet(province: widget.province, city: widget.city),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _stops.add(
        TripStop(
          order: _stops.length + 1,
          // 마지막 일차에 붙인다. 어느 날인지는 눌러서 옮길 수 있다.
          day: _stops.isEmpty ? 1 : _stops.last.day,
          name: picked.name,
          address: picked.displayAddress,
          // 시각은 서버가 동선을 짜며 채운다. 여기서 지어내면 화면에는 있는데
          // 실제 일정과 다른 시각이 보인다.
          time: '',
          latitude: picked.latitude,
          longitude: picked.longitude,
          category: picked.category,
          placeUrl: picked.placeUrl,
          contentId: picked.contentId.isEmpty ? null : picked.contentId,
        ),
      );
    });
  }

  Future<void> _makeRoute() async {
    if (_routeFuture != null ||
        _askingConsent ||
        _screenSession != AuthStore.instance.sessionVersion) {
      return;
    }
    final draft = buildManualRouteDraft(
      stops: _stops,
      startDate: widget.startDate,
      endDate: widget.endDate,
      activeStartHour: widget.activeStartHour,
      activeEndHour: widget.activeEndHour,
      transport: _draft.transport,
      province: widget.province,
      city: widget.city,
    );
    final request = draft.request;
    if (request == null) return;
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
      _routeFuture =
          (widget.route != null
                  ? widget.route!(request)
                  : TripApiService.instance.routeTrip(
                      request,
                      canSend: () => _canSend,
                    ))
              .then((response) {
                if (!_canSend) {
                  throw const TripApiException(
                    error: 'SESSION_CHANGED',
                    message: '로그인 상태가 바뀌었어요.',
                    statusCode: 409,
                  );
                }
                _result = response;
              });
      // Attach immediately, before the next frame installs the loading widget.
      // That widget still receives the same failure and restores the draft.
      _routeFuture!.ignore();
    });
  }

  void _onRouteComplete() {
    if (!_canSend) {
      _onRouteError(
        const TripApiException(
          error: 'SESSION_CHANGED',
          message: '로그인 상태가 바뀌었어요.',
          statusCode: 409,
        ),
      );
      return;
    }
    final result = _result;
    if (result == null || result.stops.isEmpty) {
      _onRouteError(const _EmptyManualRouteError());
      return;
    }
    setState(() => _routeFuture = null);
    widget.onRouted(result);
  }

  void _onRouteError(Object error) {
    final message = error is TripApiException
        ? error.message
        : '동선을 만들지 못했어요. 잠시 후 다시 시도해주세요.';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _routeFuture = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_routeFuture != null) {
      return _guardDraft(
        AppLoadingScreen(
          future: _routeFuture,
          onComplete: _onRouteComplete,
          onError: _onRouteError,
        ),
      );
    }

    final blocked = buildManualRouteDraft(
      stops: _stops,
      startDate: widget.startDate,
      endDate: widget.endDate,
      activeStartHour: widget.activeStartHour,
      activeEndHour: widget.activeEndHour,
      transport: _draft.transport,
      province: widget.province,
      city: widget.city,
    ).blockedBy;

    return _guardDraft(
      Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
              children: [
                Text(
                  '일정 직접 고치기',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.neutralScale[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '장소를 눌러 지우거나 옮기고, 끌어서 순서를 바꿔요.\n'
                  '방문 시각과 이동 시간은 동선을 만들 때 다시 계산돼요.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.neutralScale[400],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '이동수단',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final mode in TransportTheme.all)
                      ChoiceChip(
                        label: Text(mode.name),
                        selected: _draft.transport == mode.id,
                        onSelected: (_) =>
                            setState(() => _draft.transport = mode.id),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                for (int day = 1; day <= _dayCount; day++) ...[
                  _buildDayHeader(day),
                  _buildDayList(day),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 8),
                _buildAddButton(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              children: [
                NextButton(
                  onPressed: blocked == null && !_askingConsent
                      ? _makeRoute
                      : null,
                  label: '동선 만들기  →',
                  info: switch (blocked) {
                    ManualRouteBlock.tooFew => '장소를 2곳 이상 넣어 주세요',
                    ManualRouteBlock.tooMany => '한 번에 10곳까지 넣을 수 있어요',
                    null => '${_stops.length}곳으로 동선을 만들어요',
                  },
                ),
                const SizedBox(height: 12),
                PrevButton(onPressed: _cancel, label: '수정 취소'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeader(int day) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      '$day일차',
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: AppColors.neutralScale[500],
      ),
    ),
  );

  Widget _buildDayList(int day) {
    final inDay = _stopsOf(day);
    if (inDay.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.neutralScale[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '아직 넣은 장소가 없어요',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.neutralScale[300]),
        ),
      );
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: inDay.length,
      onReorder: (oldIndex, newIndex) =>
          _reorderWithinDay(day, oldIndex, newIndex),
      itemBuilder: (context, index) {
        final stop = inDay[index];
        return _buildStopTile(
          stop,
          index,
          key: ValueKey('$day-$index-${stop.name}'),
        );
      },
    );
  }

  Widget _buildStopTile(TripStop stop, int index, {required Key key}) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutralScale[100]!),
      ),
      child: ListTile(
        onTap: () => _showStopActions(stop),
        leading: CircleAvatar(
          radius: 14,
          backgroundColor: AppColors.secondaryScale[200],
          child: Text(
            '${index + 1}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.secondaryScale[500],
            ),
          ),
        ),
        title: Text(
          stop.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: stop.address.isEmpty
            ? null
            : Text(
                stop.address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.neutralScale[400],
                ),
              ),
        trailing: ReorderableDragStartListener(
          index: index,
          child: Icon(Icons.drag_handle, color: AppColors.neutralScale[300]),
        ),
      ),
    );
  }

  void _showStopActions(TripStop stop) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('이 장소 빼기'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _remove(stop);
              },
            ),
            for (int day = 1; day <= _dayCount; day++)
              if (day != stop.day)
                ListTile(
                  leading: const Icon(Icons.event_outlined),
                  title: Text('$day일차로 옮기기'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _moveToDay(stop, day);
                  },
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() => OutlinedButton.icon(
    onPressed: _addPlace,
    icon: const Icon(Icons.add),
    label: const Text('장소 추가하기'),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

/// 장소를 검색해 고르는 시트. 검색 범위는 이 일정의 지역이다.
class _PlaceSearchSheet extends StatefulWidget {
  const _PlaceSearchSheet({required this.province, required this.city});

  final String province;
  final String city;

  @override
  State<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<_PlaceSearchSheet> {
  final _controller = TextEditingController();

  List<PlaceSearchItem> _results = const [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await PlacesApiService.instance.search(
        province: widget.province,
        city: widget.city,
        query: query.isEmpty ? null : query,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
        _error = results.isEmpty ? '찾은 장소가 없어요. 다른 낱말로 찾아보세요.' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '장소를 찾지 못했어요. 잠시 후 다시 시도해주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Text(
            '${widget.province} ${widget.city}'.trim(),
            style: TextStyle(fontSize: 12, color: AppColors.neutralScale[400]),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: '장소 이름이나 종류로 찾기 (예: 카페)',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: _search,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.neutralScale[400],
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final item = _results[index];
                return ListTile(
                  title: Text(item.name, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                    item.displayAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.neutralScale[400],
                    ),
                  ),
                  trailing: const Icon(Icons.add_circle_outline),
                  onTap: () => Navigator.of(context).pop(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 장소가 비어 돌아온 응답. 사용자에게는 일반 실패와 같게 보인다.
class _EmptyManualRouteError implements Exception {
  const _EmptyManualRouteError();
}
