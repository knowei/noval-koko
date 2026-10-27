import 'package:flutter/material.dart';

import '../model/book_info.dart';
import 'motion.dart';

/// 目录页。点击章节返回其下标。
///
/// 章节多的书（几千章那种）光靠滑很麻烦，所以顶栏带一个搜索：
/// 输入章名片段（如「斗罗」「唐三」）过滤，输入纯数字则按「第 N 章」跳转。
class ChapterListPage extends StatefulWidget {
  const ChapterListPage({
    super.key,
    required this.title,
    required this.chapters,
    this.currentIndex = 0,
  });

  final String title;
  final List<BookChapter> chapters;
  final int currentIndex;

  @override
  State<ChapterListPage> createState() => _ChapterListPageState();
}

class _ChapterListPageState extends State<ChapterListPage> {
  late final ScrollController _controller = ScrollController();
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _reversed = false;
  bool _searching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients || widget.chapters.isEmpty) return;
      final int index = widget.currentIndex.clamp(0, widget.chapters.length - 1);
      final double approx = (index / widget.chapters.length) *
          _controller.position.maxScrollExtent;
      _controller.jumpTo(approx.clamp(0, _controller.position.maxScrollExtent));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// 搜索命中的章节（保持原始下标）。
  List<BookChapter> get _matched {
    final String q = _query.trim().toLowerCase();
    List<BookChapter> base = widget.chapters;
    if (q.isNotEmpty) {
      final int? num = int.tryParse(q.replaceAll(RegExp(r'[^0-9]'), ''));
      final bool pureNumber = RegExp(r'^\d+$').hasMatch(q);
      base = base.where((BookChapter c) {
        if (c.title.toLowerCase().contains(q)) return true;
        // 纯数字：按「第 N 章」找。章号从 1 开始，而 index 从 0 开始。
        if (pureNumber && num != null) {
          if (c.index + 1 == num) return true;
          // 章节标题本身可能没有章号，退一步匹配标题里的数字
          return c.title.contains('第$num') || c.title.contains('$num');
        }
        return false;
      }).toList();
    }
    return _reversed ? base.reversed.toList() : base;
  }

  void _startSearch() {
    setState(() => _searching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _searchFocus.requestFocus());
  }

  void _stopSearch() {
    setState(() {
      _searching = false;
      _query = '';
      _search.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<BookChapter> list = _matched;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _search,
                focusNode: _searchFocus,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: '搜章节名，或输入数字跳章',
                ),
                style: text.bodyLarge,
                onChanged: (String v) => setState(() => _query = v),
                onSubmitted: (String v) {
                  // 回车：命中一条就直接进那一章
                  final List<BookChapter> m = _matched;
                  if (m.length == 1) Navigator.of(context).pop(m.first.index);
                },
              )
            : Text(widget.title, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          if (_searching)
            IconButton(
              tooltip: '关闭搜索',
              icon: const Icon(Icons.close),
              onPressed: _stopSearch,
            )
          else ...<Widget>[
            IconButton(
              tooltip: '搜索章节',
              icon: const Icon(Icons.search),
              onPressed: _startSearch,
            ),
            IconButton(
              tooltip: _reversed ? '正序' : '倒序',
              icon: Icon(_reversed ? Icons.sort : Icons.sort_outlined),
              onPressed: () => setState(() => _reversed = !_reversed),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  _query.isEmpty
                      ? '${widget.chapters.length} 章'
                      : '${list.length}/${widget.chapters.length}',
                  style: text.bodySmall,
                ),
              ),
            ),
          ],
        ],
      ),
      body: list.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.search_off, size: 34, color: scheme.outline),
                  const SizedBox(height: 10),
                  Text('没有匹配的章节', style: text.bodySmall),
                  const SizedBox(height: 6),
                  Text('可以试试章节里的关键词，或直接输入章号',
                      style: text.bodySmall?.copyWith(color: scheme.outline)),
                ],
              ),
            )
          : ListView.builder(
              controller: _controller,
              itemCount: list.length,
              itemExtent: 48,
              itemBuilder: (BuildContext context, int i) {
                final BookChapter chapter = list[i];
                final bool current = chapter.index == widget.currentIndex;
                return FadeSlideIn(
                  index: i > 24 ? 24 : i,
                  rise: 6,
                  duration: kMotionFast,
                  child: ListTile(
                    dense: true,
                    selected: current,
                    title: Text(
                      chapter.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: current ? scheme.primary : null,
                        fontWeight: current ? FontWeight.w700 : null,
                      ),
                    ),
                    trailing: chapter.isVip
                        ? Icon(Icons.lock_outline, size: 16, color: scheme.outline)
                        : null,
                    onTap: () => Navigator.of(context).pop(chapter.index),
                  ),
                );
              },
            ),
    );
  }
}
