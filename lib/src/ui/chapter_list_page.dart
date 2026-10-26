import 'package:flutter/material.dart';

import '../model/book_info.dart';
import 'motion.dart';

/// 目录页。点击章节返回其下标。
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
  bool _reversed = false;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<BookChapter> list = _reversed
        ? widget.chapters.reversed.toList()
        : widget.chapters;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          IconButton(
            tooltip: _reversed ? '正序' : '倒序',
            icon: Icon(_reversed ? Icons.sort : Icons.sort_outlined),
            onPressed: () => setState(() => _reversed = !_reversed),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text('${widget.chapters.length} 章',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        controller: _controller,
        itemCount: list.length,
        itemExtent: 48,
        itemBuilder: (BuildContext context, int i) {
          final BookChapter chapter = list[i];
          final bool current = chapter.index == widget.currentIndex;
          return FadeSlideIn(
            index: i,
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
                  fontWeight: current ? FontWeight.w600 : null,
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
