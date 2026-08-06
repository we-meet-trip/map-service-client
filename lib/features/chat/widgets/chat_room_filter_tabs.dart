import 'package:flutter/material.dart';
import '../models/chat_room.dart';

class ChatRoomFilterTabs extends StatefulWidget {
  const ChatRoomFilterTabs({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final ChatRoomFilter selected;
  final ValueChanged<ChatRoomFilter> onChanged;

  @override
  State<ChatRoomFilterTabs> createState() => _ChatRoomFilterTabsState();
}

class _ChatRoomFilterTabsState extends State<ChatRoomFilterTabs> {
  static const _labels = ['전체', '예정된 일정', '지난 일정'];
  static const _filters = [ChatRoomFilter.all, ChatRoomFilter.upcoming, ChatRoomFilter.past];

  final _stackKey = GlobalKey();
  final List<GlobalKey> _tabKeys = List.generate(3, (_) => GlobalKey());

  double _pillLeft = 0;
  double _pillWidth = 0;
  bool _measured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _movePill());
  }

  @override
  void didUpdateWidget(ChatRoomFilterTabs old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _movePill());
    }
  }

  void _movePill() {
    final idx = _filters.indexOf(widget.selected);
    final tabCtx = _tabKeys[idx].currentContext;
    final stackCtx = _stackKey.currentContext;
    if (tabCtx == null || stackCtx == null) return;

    final tabBox = tabCtx.findRenderObject() as RenderBox;
    final stackBox = stackCtx.findRenderObject() as RenderBox;
    final offset = tabBox.localToGlobal(Offset.zero, ancestor: stackBox);

    setState(() {
      _pillLeft = offset.dx;
      _pillWidth = tabBox.size.width;
      _measured = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
          key: _stackKey,
          children: [
            if (_measured)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                left: _pillLeft,
                top: 0,
                bottom: 0,
                width: _pillWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE4FB),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < _labels.length; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  GestureDetector(
                    key: _tabKeys[i],
                    onTap: () => widget.onChanged(_filters[i]),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: Colors.transparent,
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        style: TextStyle(
                          fontSize: 15,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w700,
                          color: widget.selected == _filters[i]
                              ? const Color(0xFF6012DF)
                              : const Color(0xFF9989B2),
                        ),
                        child: Text(_labels[i]),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
    );
  }
}
