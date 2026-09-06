import 'package:flutter/material.dart';
import '../../core/api/moderation_api_service.dart';
import '../../core/state/auth_store.dart';
import 'moderation_center_screen.dart';

Future<ModerationReport?> showContentReport(
  BuildContext context,
  ReportTarget target, {
  ModerationApiService? service,
}) {
  if (!target.valid) return Future.value(null);
  return showDialog<ModerationReport>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ContentReportDialog(target: target, service: service),
  );
}

class ContentReportDialog extends StatefulWidget {
  const ContentReportDialog({super.key, required this.target, this.service});
  final ReportTarget target;
  final ModerationApiService? service;
  @override
  State<ContentReportDialog> createState() => _ContentReportDialogState();
}

class _ContentReportDialogState extends State<ContentReportDialog> {
  final _description = TextEditingController();
  final _sessionVersion = AuthStore.instance.sessionVersion;
  ReportReason? _reason;
  ReportSubmission? _submission;
  ModerationReport? _accepted;
  bool _sending = false;
  String? _error;
  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending || _accepted != null) return;
    if (_sessionVersion != AuthStore.instance.sessionVersion) {
      setState(() => _error = '로그인 상태가 바뀌었어요. 이 창을 닫고 다시 신고해주세요.');
      return;
    }
    if (_reason == null ||
        (widget.target.type == ReportContentType.vision &&
            _description.text.trim().isEmpty)) {
      setState(() => _error = '신고 사유와 필요한 설명을 입력해주세요.');
      return;
    }
    _submission ??= ReportSubmission(
      target: widget.target,
      reason: _reason!,
      clientRequestId: newReportRequestId(),
      description: _description.text,
    );
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final report = await (widget.service ?? ModerationApiService.instance)
          .report(_submission!);
      if (mounted) setState(() => _accepted = report);
    } catch (_) {
      if (mounted) {
        setState(() => _error = '접수 결과를 확인하지 못했어요. 같은 신고로 다시 시도해주세요.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_sending,
    child: AlertDialog(
      title: Text(
        _accepted != null ? '신고가 접수됐어요' : '${widget.target.type.label} 신고',
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: _accepted != null
              ? Text(
                  '접수 번호 ${_accepted!.reportId}\n처리 상태: ${_accepted!.statusLabel}\n신고·차단 관리에서 진행 상태를 확인할 수 있어요.',
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('운영자가 내용을 검토합니다. 신고만으로 상대가 차단되지는 않아요.'),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<ReportReason>(
                      initialValue: _reason,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '신고 사유'),
                      items: ReportReason.values
                          .map(
                            (reason) => DropdownMenuItem(
                              value: reason,
                              child: Text(reason.label),
                            ),
                          )
                          .toList(),
                      onChanged: _submission != null || _sending
                          ? null
                          : (reason) => setState(() => _reason = reason),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _description,
                      enabled: _submission == null && !_sending,
                      minLines: 3,
                      maxLines: 5,
                      maxLength: 1000,
                      decoration: InputDecoration(
                        labelText:
                            widget.target.type == ReportContentType.vision
                            ? '문제가 된 답변과 신고 이유 (필수)'
                            : '추가 설명 (선택)',
                        helperText: '비밀번호·연락처 등 불필요한 개인정보는 적지 마세요.',
                        helperMaxLines: 2,
                      ),
                    ),
                    if (widget.target.type == ReportContentType.vision)
                      const Text('사진·카메라 영상은 신고에 첨부되지 않아요.'),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
      actions: _accepted != null
          ? [
              TextButton(
                onPressed: () => Navigator.of(context).pop(_accepted),
                child: const Text('확인'),
              ),
            ]
          : [
              TextButton(
                onPressed: _sending ? null : () => Navigator.of(context).pop(),
                child: const Text('닫기'),
              ),
              FilledButton(
                onPressed: _sending ? null : _submit,
                child: Text(
                  _sending
                      ? '접수 중…'
                      : _submission == null
                      ? '신고 접수'
                      : '같은 신고 재시도',
                ),
              ),
            ],
    ),
  );
}

class ContentReportActions extends StatelessWidget {
  const ContentReportActions({super.key, required this.target});
  final ReportTarget target;
  @override
  Widget build(BuildContext context) {
    if (!target.valid) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      children: [
        TextButton.icon(
          icon: const Icon(Icons.flag_outlined, size: 18),
          label: const Text('이 결과 신고'),
          onPressed: () => showContentReport(context, target),
        ),
        TextButton(
          onPressed: () => openModerationCenter(context),
          child: const Text('신고 처리 상태'),
        ),
      ],
    );
  }
}
