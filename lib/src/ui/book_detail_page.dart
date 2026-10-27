import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../model/book_info.dart';
import '../model/shelf_book.dart';
import 'chapter_list_page.dart';
import 'switch_source_sheet.dart';
import 'reader/comic_reader.dart';
import 'reader/text_reader.dart';
import 'motion.dart';
import 'widgets.dart';

/// 书籍详情：介绍 + 目录 + 开始阅读 / 加入书架。
class BookDetailPage extends StatefulWidget {
  const BookDetailPage({super.key, required this.book});

  final ShelfBook book;

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  late ShelfBook _book = widget.book;

  List<BookChapter> _chapters = <BookChapter>[];
  bool _loading = true;
  String? _error;
  bool _inShelf = false;
  bool _introExpanded = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final AppState state = context.read<AppState>();
    _inShelf = await state.inShelf(_book.bookUrl);
    if (!mounted) return;
    setState(() {});
    await _loadChapters(refresh: false);
  }

  Future<void> _loadChapters({required bool refresh}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<BookChapter> list = await context
          .read<AppState>()
          .loadChapters(_book, refresh: refresh);
      if (!mounted) return;
      setState(() {
        _chapters = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleShelf() async {
    final AppState state = context.read<AppState>();
    if (_inShelf) {
      await state.removeFromShelf(_book.bookUrl);
      if (!mounted) return;
      setState(() => _inShelf = false);
      _toast('已移出书架');
    } else {
      await state.addToShelf(_book);
      if (!mounted) return;
      setState(() => _inShelf = true);
      _toast('已加入书架');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 1)));
  }

  Future<void> _read([int? index]) async {
    if (_chapters.isEmpty) {
      _toast('目录为空，先刷新目录');
      return;
    }
    final AppState state = context.read<AppState>();
    final int start =
        (index ?? _book.lastReadIndex).clamp(0, _chapters.length - 1);
    if (!await state.inShelf(_book.bookUrl)) {
      await state.addToShelf(_book);
    }
    if (!mounted) return;

    await Navigator.of(context).push<void>(
      fadeSlideRoute<void>(
        _book.isComic
            ? ComicReaderPage(book: _book, chapters: _chapters, index: start)
            : TextReaderPage(book: _book, chapters: _chapters, index: start),
        duration: kMotionSlow,
      ),
    );
    if (!mounted) return;
    setState(() => _inShelf = true);
  }

  /// 当前进度落在哪一章的标题上——换源时用它把进度挪过去。
  String? get _currentChapterTitle {
    final int i = _book.lastReadIndex;
    if (i >= 0 && i < _chapters.length) return _chapters[i].title;
    return null;
  }

  Future<void> _openSwitchSource() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final SourceCandidate? cand = await showModalBottomSheet<SourceCandidate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => SwitchSourceSheet(book: _book),
    );
    if (cand == null || !mounted) return;
    final String? title = _currentChapterTitle;
    setState(() => _loading = true);
    try {
      final SwitchResult r = await context
          .read<AppState>()
          .switchSource(_book, cand, chapterTitle: title);
      if (!mounted) return;
      setState(() {
        _book = r.book;
        _chapters = r.chapters;
        _loading = false;
      });
      messenger.showSnackBar(SnackBar(
        content: Text('已换到「${cand.source.name}」，共 ${r.chapters.length} 章'),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      messenger.showSnackBar(SnackBar(content: Text('换源失败：$e')));
    }
  }


  Future<void> _openCatalog() async {
    if (_chapters.isEmpty) {
      _toast('目录为空');
      return;
    }
    final int? selected = await Navigator.of(context).push<int>(
      fadeSlideRoute<int>(
        ChapterListPage(
          title: _book.name,
          chapters: _chapters,
          currentIndex: _book.lastReadIndex,
        ),
      ),
    );
    if (selected != null) await _read(selected);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasProgress = _book.lastReadIndex > 0 || _book.lastReadOffset > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_book.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          IconButton(
            tooltip: '刷新目录',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : () => _loadChapters(refresh: true),
          ),
        ],
      ),
      body: ListView(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                BookCover(
                  url: _book.cover,
                  name: _book.name,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _book.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _book.author.isEmpty ? '佚名' : _book.author,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          _chip(
                            _book.isComic ? '漫画' : '小说',
                            theme.colorScheme.primaryContainer,
                          ),
                          if (_book.kind.isNotEmpty) _chip(_book.kind, null),
                          if (_book.sourceName.isNotEmpty)
                            _chip(_book.sourceName, null),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 操作按钮单独占一行：窄屏（手机）两个按钮平分整行，
          // 宽屏最多 460 逻辑像素，避免挤在封面右侧折成两行。
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
            // Align 让 ConstrainedBox 拿到松约束（ListView 的交叉轴是紧宽度），
            // 否则 maxWidth 不生效、桌面端按钮会被拉满整行。
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _loading ? null : () => _read(),
                        icon: const Icon(Icons.menu_book, size: 18),
                        label: Text(
                          hasProgress ? '继续阅读' : '开始阅读',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _toggleShelf,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                        ),
                        child: Text(
                          _inShelf ? '移出书架' : '加入书架',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _openSwitchSource,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('换源'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_book.latestChapter.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                '最新：${_book.latestChapter}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ),
          if (_book.intro.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _book.intro,
                    maxLines: _introExpanded ? null : 4,
                    overflow: _introExpanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
                  ),
                  InkWell(
                    onTap: () =>
                        setState(() => _introExpanded = !_introExpanded),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        _introExpanded ? '收起' : '展开',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: <Widget>[
                Text('目录', style: theme.textTheme.titleMedium),
                const SizedBox(width: 8),
                Text(
                  _chapters.isNotEmpty
                      ? '共 ${_chapters.length} 章'
                      : widget.book.totalChapters > 0
                          ? '共 ${widget.book.totalChapters} 章'
                          : '目录加载中…',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
                const Spacer(),
                if (_chapters.length > 6)
                  TextButton(
                    onPressed: _openCatalog,
                    child: const Text('全部目录'),
                  ),
              ],
            ),
          ),
          _buildChapters(theme),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _chip(String text, Color? background) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background ?? theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: background == null
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Widget _buildChapters(ThemeData theme) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            Text(
              '目录加载失败\n$_error',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _loadChapters(refresh: true),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_chapters.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('还没有目录')),
      );
    }

    final List<BookChapter> preview =
        _chapters.length <= 6 ? _chapters : _chapters.sublist(0, 6);

    return Column(
      children: <Widget>[
        for (final BookChapter c in preview)
          ListTile(
            dense: true,
            title: Text(
              c.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: c.isVip
                ? Icon(Icons.lock_outline,
                    size: 16, color: theme.colorScheme.outline)
                : null,
            onTap: () => _read(c.index),
          ),
      ],
    );
  }
}

