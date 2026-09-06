import 'package:flutter/material.dart';
import '../../core/api/moderation_api_service.dart';
import '../../core/state/auth_store.dart';

Future<void> openModerationCenter(
  BuildContext context, {
  ModerationApiService? service,
  Future<void> Function()? onBlocksChanged,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ModerationCenterScreen(
        service: service,
        onBlocksChanged: onBlocksChanged,
      ),
    ),
  );
}

class ModerationCenterScreen extends StatefulWidget {
  const ModerationCenterScreen({super.key, this.service, this.onBlocksChanged});
  final ModerationApiService? service;
  final Future<void> Function()? onBlocksChanged;
  @override
  State<ModerationCenterScreen> createState() => _ModerationCenterScreenState();
}

class _ModerationCenterScreenState extends State<ModerationCenterScreen> {
  late final _service = widget.service ?? ModerationApiService.instance;
  List<ModerationReport>? _reports;
  List<BlockedUser>? _blocks;
  String? _error;
  bool _loading = false;
  int _revision = 0;
  final _sessionVersion = AuthStore.instance.sessionVersion;
  final Set<int> _pendingUnblocks = {};
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    if (_sessionVersion != AuthStore.instance.sessionVersion) {
      setState(() {
        _reports = null;
        _blocks = null;
        _error = '로그인 상태가 바뀌었어요. 이 화면을 다시 열어주세요.';
      });
      return;
    }
    final revision = _revision;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reports = await _service.reports();
      if (_sessionVersion != AuthStore.instance.sessionVersion) return;
      final blocks = await _service.blocks();
      if (mounted &&
          revision == _revision &&
          _sessionVersion == AuthStore.instance.sessionVersion) {
        setState(() {
          _reports = reports;
          _blocks = blocks;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '신고·차단 내역을 불러오지 못했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          if (_sessionVersion != AuthStore.instance.sessionVersion) {
            _reports = null;
            _blocks = null;
            _error = '로그인 상태가 바뀌었어요. 이 화면을 다시 열어주세요.';
          }
        });
      }
    }
  }

  Future<void> _unblock(BlockedUser user) async {
    if (_pendingUnblocks.contains(user.userId) ||
        _sessionVersion != AuthStore.instance.sessionVersion) {
      return;
    }
    setState(() => _pendingUnblocks.add(user.userId));
    try {
      await _service.unblock(user.userId);
      if (!mounted) return;
      _revision++;
      setState(
        () => _blocks = _blocks?.where((b) => b.userId != user.userId).toList(),
      );
      // The server mutation already succeeded. A failed history reload must not
      // claim that unblocking failed, nor restore the stale block entry.
      try {
        await widget.onBlocksChanged?.call();
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('차단을 해제했어요.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('차단을 해제하지 못했어요. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _pendingUnblocks.remove(user.userId));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('신고·차단 관리'),
      actions: [
        IconButton(
          tooltip: '다시 불러오기',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          '신고와 차단 도움말',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          '채팅 메시지 옆 메뉴에서 해당 메시지를 신고하거나 상대를 차단할 수 있어요. '
          '생성 일정과 Vision 답변은 결과의 신고 버튼을 이용해주세요.\n\n'
          '신고는 운영자가 검토하며 처리 상태가 아래에 표시됩니다. 신고는 상대에게 알리지 않아요. '
          '차단하면 상대의 채팅 메시지가 숨겨집니다. 차단과 채팅방 나가기는 별개예요. '
          '긴급한 위험이 있다면 112 또는 119에 연락해주세요.',
        ),
        const SizedBox(height: 24),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) ...[
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(
            onPressed: _loading ? null : _load,
            child: const Text('다시 시도'),
          ),
        ],
        const Text(
          '내 신고 처리 상태',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        if (_reports?.isEmpty == true)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('접수한 신고가 없어요.'),
          ),
        for (final report in _reports ?? <ModerationReport>[])
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('신고 ${report.reportId} · ${report.statusLabel}'),
            subtitle: Text(
              '${_formatDate(report.createdAt)}${report.resolutionLabel == null ? '' : '\n${report.resolutionLabel}'}',
            ),
            leading: const Icon(Icons.flag_outlined),
          ),
        const SizedBox(height: 24),
        const Text(
          '차단한 사용자',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        if (_blocks?.isEmpty == true)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('차단한 사용자가 없어요.'),
          ),
        for (final user in _blocks ?? <BlockedUser>[])
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(user.label),
            trailing: TextButton(
              onPressed: _pendingUnblocks.contains(user.userId)
                  ? null
                  : () => _unblock(user),
              child: Text(
                _pendingUnblocks.contains(user.userId) ? '해제 중…' : '차단 해제',
              ),
            ),
          ),
      ],
    ),
  );

  String _formatDate(DateTime time) {
    final local = time.toLocal();
    return '${local.year}.${local.month.toString().padLeft(2, '0')}.${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')} 접수';
  }
}
