import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/moderation_api_service.dart';
import '../../features/moderation/report_dialog.dart';
import '../../core/api/review_api_service.dart';
import '../../core/state/auth_store.dart';
import 'external_ai_consent.dart';

/// Opening a place only reads a cached summary. New AI processing is explicit.
class ReviewSummarySection extends StatefulWidget {
  const ReviewSummarySection({
    super.key,
    required this.query,
    required this.resultBuilder,
  });
  final String query;
  final Widget Function(List<String>) resultBuilder;
  @override
  State<ReviewSummarySection> createState() => _ReviewSummarySectionState();
}

class _ReviewSummarySectionState extends State<ReviewSummarySection> {
  final _gate = ExternalAiConsentGate.instance;
  final _api = ReviewApiService.instance;
  List<String> _bullets = const [];
  bool _loading = true;
  bool _generating = false;
  String? _message;
  String? _attemptId;
  ExternalAiPermission? _permission;
  int _generation = 0;
  late int _session;

  @override
  void initState() {
    super.initState();
    _session = AuthStore.instance.sessionVersion;
    _gate.addListener(_consentChanged);
    AuthStore.instance.sessionChanges.addListener(_sessionChanged);
    _loadCached();
  }

  @override
  void didUpdateWidget(ReviewSummarySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _generation++;
      _permission = null;
      _attemptId = null;
      _bullets = const [];
      _message = null;
      _generating = false;
      _loading = true;
      _loadCached();
    }
  }

  void _sessionChanged() {
    if (!mounted || _session == AuthStore.instance.sessionVersion) return;
    setState(() {
      _session = AuthStore.instance.sessionVersion;
      _generation++;
      _permission = null;
      _attemptId = null;
      _bullets = const [];
      _loading = _generating = false;
      _message = '로그인 상태가 바뀌었어요. 장소를 다시 열어주세요.';
    });
  }

  void _consentChanged() {
    if (!mounted || _permission == null || _permission!.isCurrentSession) {
      return;
    }
    setState(() {
      _generation++;
      _permission = null;
      _attemptId = null;
      _generating = false;
      _message = '동의가 철회되어 진행 중인 응답을 표시하지 않았어요.';
    });
  }

  Future<void> _loadCached() async {
    final generation = _generation;
    final session = _session;
    final bullets = await _api.fetchSummary(widget.query);
    if (!mounted ||
        generation != _generation ||
        session != AuthStore.instance.sessionVersion) {
      return;
    }
    setState(() {
      _bullets = bullets;
      _loading = false;
    });
  }

  Future<void> _generate() async {
    if (_loading || _generating) return;
    final generation = _generation;
    final session = AuthStore.instance.sessionVersion;
    setState(() {
      _generating = true;
      _message = null;
    });
    try {
      final permission = await ensureExternalAiConsent(
        context,
        ExternalAiScope.reviewSummary,
      );
      if (!mounted ||
          generation != _generation ||
          permission == null ||
          session != AuthStore.instance.sessionVersion ||
          !permission.isCurrentSession) {
        return;
      }
      _permission = permission;
      bool canSend() =>
          mounted &&
          generation == _generation &&
          session == AuthStore.instance.sessionVersion &&
          permission.isCurrentSession;
      _attemptId ??= newClientRequestId();
      final bullets = await _api.generateSummary(
        widget.query,
        clientRequestId: _attemptId!,
        canSend: canSend,
      );
      if (!canSend()) return;
      setState(() {
        _bullets = bullets;
        _attemptId = null;
        _message = bullets.isEmpty ? '요약할 수 있는 공개 리뷰가 부족해요.' : null;
      });
    } catch (error) {
      if (!mounted ||
          generation != _generation ||
          session != AuthStore.instance.sessionVersion) {
        return;
      }
      setState(
        () => _message = error is ApiException && error.statusCode == 429
            ? '요약 요청이 많아요. 잠시 후 다시 시도해주세요.'
            : error is ApiException && error.statusCode == 409
            ? '요청을 처리 중이에요. 잠시 후 다시 눌러주세요.'
            : '리뷰 요약 요청에 실패했어요. 다시 시도해주세요.',
      );
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _generating = false);
      }
    }
  }

  @override
  void dispose() {
    _gate.removeListener(_consentChanged);
    AuthStore.instance.sessionChanges.removeListener(_sessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_bullets.isNotEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.resultBuilder(_bullets),
          TextButton.icon(
            key: const ValueKey('report-review-summary'),
            icon: const Icon(Icons.flag_outlined, size: 18),
            label: const Text('리뷰 요약 신고'),
            onPressed: () {
              final explanation = '${widget.query}\n${_bullets.join('\n')}';
              showContentReport(
                context,
                const ReportTarget.reviewSummary(),
                initialDescription: String.fromCharCodes(
                  // Reserve at least 100 UTF-16 units for the user’s explanation.
                  explanation.runes.take(450),
                ),
              );
            },
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_message != null) Text(_message!),
        OutlinedButton.icon(
          key: const ValueKey('generate-review-summary'),
          onPressed: _generating ? null : _generate,
          icon: _generating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(_generating ? '리뷰 요약 요청 중' : 'AI 리뷰 요약 만들기'),
        ),
      ],
    );
  }
}
