import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../model/book_info.dart';
import '../../model/shelf_book.dart';
import '../chapter_list_page.dart';
import '../motion.dart';
import 'read_theme.dart';
import 'reader_font.dart';

/// 文本阅读器：横向翻页。
class TextReaderPage extends StatefulWidget {
  const TextReaderPage({
    super.key,
    required this.book,
    required this.chapters,
    required this.index,
  });

  final ShelfBook book;
  final List<BookChapter> chapters;
  final int index;

  @override
  State<TextReaderPage> createState() => _TextReaderPageState();
}

class _TextReaderPageState extends State<TextReaderPage> {
  late int _index = widget.index;
  final Map<int, String> _cache = <int, String>{};
  final PageController _pageController = PageController();

  String _text = '';
  bool _loading = true;
  String? _error;
  bool _barVisible = false;
  int _page = 0;

  List<String> _pages = const <String>[];
  String _pagesKey = '';
  double _pendingRestore = -1;

  /// 滚动模式用
  final ScrollController _scroll = ScrollController();
  double _scrollFrac = 0;

  /// 上一页翻到章首时，加载完要跳到最后页
  bool _jumpToLast = false;

  @override
  void initState() {
    super.initState();
    if (_index == widget.book.lastReadIndex && widget.book.lastReadOffset > 0) {
      _pendingRestore = widget.book.lastReadOffset.clamp(0.0, 1.0);
    }
    _load(_index);
  }

  AppState? _appState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState = context.read<AppState>();
  }

  @override
  void dispose() {
    // 退出阅读器时兜底存一次：滚动模式只滚了一点点、或刚进来就退出的情况
    // 之前会丢进度，回到书架再进就回到旧章节。
    final double offset = _appState == null
        ? 0
        : (_appState!.prefs.scrollMode
            ? _scrollFrac
            : (_pages.length <= 1 ? 0 : _page / (_pages.length - 1)));
    _appState?.saveProgress(widget.book, _index, offset: offset);
    _pageController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  BookChapter? get _chapter =>
      _index >= 0 && _index < widget.chapters.length
          ? widget.chapters[_index]
          : null;

  Future<void> _load(int index) async {
    final BookChapter? chapter = index >= 0 && index < widget.chapters.length
        ? widget.chapters[index]
        : null;
    if (chapter == null) return;

    setState(() {
      _loading = true;
      _error = null;
      _text = '';
      _pages = const <String>[];
      _pagesKey = '';
      _page = 0;
    });

    final String? cached = _cache[index];
    if (cached != null) {
      setState(() {
        _text = cached;
        _loading = false;
      });
      return;
    }

    try {
      final dynamic content =
          await context.read<AppState>().loadContent(widget.book, chapter);
      final String text = htmlToPlainText(content.text as String);
      _cache[index] = text;
      if (!mounted) return;
      setState(() {
        _text = text;
        _loading = false;
      });
      await context.read<AppState>().saveProgress(widget.book, index);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _goChapter(int index, {bool toLast = false}) {
    if (index < 0 || index >= widget.chapters.length) return;
    _pendingRestore = -1;
    _jumpToLast = toLast;
    _scrollFrac = toLast ? 1 : 0;
    setState(() => _index = index);
    if (!toLast && _pageController.hasClients) _pageController.jumpToPage(0);
    if (!toLast && _scroll.hasClients) _scroll.jumpTo(0);
    _load(index);
  }

  /// 上一页：本章第一页时退回上一章的最后一页
  void _prevPage() {
    if (_page > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    } else if (_index > 0) {
      _goChapter(_index - 1, toLast: true);
    }
  }

  /// 下一页：本章最后一页时进入下一章
  void _nextPage() {
    if (_page < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    } else if (_index < widget.chapters.length - 1) {
      _goChapter(_index + 1);
    }
  }

  Future<void> _openCatalog() async {
    final int? selected = await Navigator.of(context).push<int>(
      fadeSlideRoute<int>(
        ChapterListPage(
          title: widget.book.name,
          chapters: widget.chapters,
          currentIndex: _index,
        ),
      ),
    );
    if (selected != null && selected != _index) _goChapter(selected);
  }

  // ------------------------------------------------------------- 分页计算

  List<String> _paginate(double width, double height, double fontSize,
      double lineHeight, String fontId) {
    // key 里必须带上正文本身：加载中（_text 为空）时的分页结果不能拿来复用，
    // 否则正文回来之后仍然只有一页空白。
    final String key =
        '${identityHashCode(_text)}_${_text.length}_'
        '${width.round()}x${height.round()}_'
        '${fontSize.toStringAsFixed(1)}_${lineHeight.toStringAsFixed(2)}_$fontId';
    if (key == _pagesKey) return _pages;

    final List<String> pages =
        _splitPages(_text, width, height, fontSize, lineHeight, fontId);
    _pagesKey = key;
    _pages = pages.isEmpty ? <String>[''] : pages;
    return _pages;
  }

  List<String> _splitPages(String text, double width, double height,
      double fontSize, double lineHeight, String fontId) {
    if (text.isEmpty || width <= 0 || height <= 0) return <String>[];

    final TextStyle style = ReaderFont.byId(fontId)
        .apply(fontSize: fontSize, lineHeight: lineHeight);
    final TextPainter painter = TextPainter(
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    );

    final List<String> pages = <String>[];
    int start = 0;
    while (start < text.length) {
      int low = start + 1;
      int high = text.length;
      int best = start + 1;
      while (low <= high) {
        final int mid = (low + high) ~/ 2;
        painter.text = TextSpan(text: text.substring(start, mid), style: style);
        painter.layout(maxWidth: width);
        if (painter.height <= height) {
          best = mid;
          low = mid + 1;
        } else {
          high = mid - 1;
        }
      }

      int end = best;
      if (end < text.length) {
        final String window = text.substring(start, end);
        final int cut =
            window.lastIndexOf(RegExp(r'[\n。！？…”」』）]'));
        if (cut > window.length * 0.6) end = start + cut + 1;
      }
      pages.add(text.substring(start, end).trim());
      start = end;
    }
    return pages;
  }

  // ------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final ReadPrefs prefs = state.prefs;
    final ReadPalette palette =
        ReadPalette.all[prefs.theme.clamp(0, ReadPalette.all.length - 1)];

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints c) {
                  final List<String> pages = _paginate(
                    c.maxWidth - prefs.padding * 2,
                    c.maxHeight - prefs.padding * 2 - 40,
                    prefs.fontSize,
                    prefs.lineHeight,
                    prefs.fontId,
                  );
                  if (!prefs.scrollMode &&
                      _pendingRestore >= 0 &&
                      pages.length > 1) {
                    final double fraction = _pendingRestore;
                    _pendingRestore = -1;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!_pageController.hasClients) return;
                      final int target =
                          (fraction * (pages.length - 1)).round();
                      _pageController.jumpToPage(target);
                      setState(() => _page = target);
                    });
                  }

                  if (_jumpToLast && pages.length > 1 && !prefs.scrollMode) {
                    _jumpToLast = false;
                    final int target = pages.length - 1;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!_pageController.hasClients) return;
                      _pageController.jumpToPage(target);
                      setState(() => _page = target);
                    });
                  }

                  if (prefs.scrollMode &&
                      (_pendingRestore >= 0 || _jumpToLast)) {
                    final double frac =
                        _jumpToLast ? 1 : _pendingRestore.clamp(0.0, 1.0);
                    _pendingRestore = -1;
                    _jumpToLast = false;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!_scroll.hasClients) return;
                      _scroll.jumpTo(
                          frac * _scroll.position.maxScrollExtent);
                    });
                  }

                  return Column(
                    children: <Widget>[
                      _ChapterHeader(
                        title: _chapter?.title ?? '',
                        palette: palette,
                        fontSize: prefs.fontSize,
                      ),
                      Expanded(
                        // 切章/切模式时淡入，避免正文「啪」地换掉
                        child: FadeSwitch(
                          child: KeyedSubtree(
                            key: ValueKey<String>(
                                'ch-$_index-${prefs.scrollMode ? 's' : 'p'}'),
                            child: _buildBody(pages, prefs, palette),
                          ),
                        ),
                      ),
                      _FooterBar(
                        index: _index,
                        count: widget.chapters.length,
                        palette: palette,
                        label: prefs.scrollMode
                            ? '${(_scrollFrac * 100).round()}%'
                            : '${math.min(_page + 1, math.max(pages.length, 1))}'
                                '/${pages.length}',
                      ),
                    ],
                  );
                },
              ),
            ),
            _buildTopBar(palette, visible: _barVisible),
            _buildBottomBar(palette, prefs, visible: _barVisible),
          ],
        ),
      ),
    );
  }

  /// 空态/错误态也要能点一下唤出菜单——否则用户会卡在「什么都点不出来」。
  Widget _tapWrap(Widget child) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleBar,
      child: child,
    );
  }

  Widget _buildBody(List<String> pages, ReadPrefs prefs, ReadPalette palette) {
    if (_loading) {
      return _tapWrap(
        Center(child: CircularProgressIndicator(color: palette.muted)),
      );
    }
    if (_error != null) {
      return _tapWrap(
        _ErrorView(
          message: _error!,
          palette: palette,
          onRetry: () => _load(_index),
          onSwitch: () => Navigator.of(context).maybePop(),
        ),
      );
    }
    // 有些源的首章（新书感言/公告）本身就没有正文，别给用户一个纯白页
    if (_text.trim().isEmpty) {
      final bool hasNext = _index + 1 < widget.chapters.length;
      return _tapWrap(
        Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.article_outlined, size: 42, color: palette.muted),
                const SizedBox(height: 12),
                Text('本章没有正文内容',
                    style: TextStyle(color: palette.muted, fontSize: 14)),
                const SizedBox(height: 6),
                Text('「${_chapter?.title ?? ''}」',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.muted, fontSize: 12)),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    OutlinedButton(
                      onPressed: () => _load(_index),
                      child: const Text('重新加载'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('换个源'),
                    ),
                    if (hasNext)
                      FilledButton(
                        onPressed: () => _goChapter(_index + 1),
                        child: const Text('下一章'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (prefs.scrollMode) return _buildScrollBody(prefs, palette);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (TapUpDetails d) {
        final double w = MediaQuery.sizeOf(context).width;
        if (d.localPosition.dx < w * 0.3) {
          _prevPage();
        } else if (d.localPosition.dx > w * 0.7) {
          _nextPage();
        } else {
          _toggleBar();
        }
      },
      child: PageView.builder(
        controller: _pageController,
        itemCount: pages.length,
        onPageChanged: (int i) {
          setState(() => _page = i);
          context.read<AppState>().saveProgress(
                widget.book,
                _index,
                offset: pages.length <= 1 ? 0 : i / (pages.length - 1),
              );
        },
        itemBuilder: (BuildContext context, int i) => Padding(
          padding: EdgeInsets.symmetric(horizontal: prefs.padding),
          child: Text(
            pages[i],
            style: ReaderFont.byId(prefs.fontId).apply(
              fontSize: prefs.fontSize,
              lineHeight: prefs.lineHeight,
              color: palette.text,
            ),
          ),
        ),
      ),
    );
  }

  /// 上下滚动模式：整章连续排版，滚动即读，进度按百分比存。
  Widget _buildScrollBody(ReadPrefs prefs, ReadPalette palette) {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification n) {
        final double max = n.metrics.maxScrollExtent;
        if (max > 0) {
          _scrollFrac = (n.metrics.pixels / max).clamp(0.0, 1.0);
        }
        if (n is ScrollEndNotification) {
          context.read<AppState>().saveProgress(
                widget.book,
                _index,
                offset: _scrollFrac,
              );
        }
        return false;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleBar,
        // 纵向交给 ListView 滚动；横向滑动用来切上一章 / 下一章
        onHorizontalDragEnd: (DragEndDetails d) => _onSwipe(d.primaryVelocity),
        child: ListView(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(prefs.padding, 0, prefs.padding, 28),
          children: <Widget>[
            Text(
              _text,
              style: ReaderFont.byId(prefs.fontId).apply(
                fontSize: prefs.fontSize,
                lineHeight: prefs.lineHeight,
                color: palette.text,
              ),
            ),
            const SizedBox(height: 26),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (_index > 0)
                  TextButton(
                    onPressed: () => _goChapter(_index - 1),
                    child: const Text('上一章'),
                  ),
                const SizedBox(width: 18),
                if (_index < widget.chapters.length - 1)
                  TextButton(
                    onPressed: () => _goChapter(_index + 1),
                    child: const Text('下一章'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _toggleBar() => setState(() => _barVisible = !_barVisible);

  /// 横向滑动（滚动模式）：左滑下一屏，滑到底再滑进下一章；右滑上一屏，到顶再滑回上一章。
  void _onSwipe(double? velocity) {
    if (!_scroll.hasClients) return;
    final double v = velocity ?? 0;
    if (v.abs() < 200) return;
    final double max = _scroll.position.maxScrollExtent;
    final double step = _scroll.position.viewportDimension * 0.9;
    if (v < 0) {
      // 左滑：往下走
      if (_scroll.offset >= max - 8) {
        if (_index < widget.chapters.length - 1) _goChapter(_index + 1);
      } else {
        _scroll.animateTo(
          (_scroll.offset + step).clamp(0.0, max),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    } else {
      // 右滑：往上走
      if (_scroll.offset <= 8) {
        if (_index > 0) _goChapter(_index - 1, toLast: true);
      } else {
        _scroll.animateTo(
          (_scroll.offset - step).clamp(0.0, max),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Widget _buildTopBar(ReadPalette palette, {required bool visible}) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, -1),
          duration: kMotionMid,
          curve: kMotionCurve,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: kMotionFast,
            child: Material(
              color: palette.background,
              elevation: 1,
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: <Widget>[
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: palette.text),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        widget.book.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: palette.text, fontSize: 16),
                      ),
                    ),
                    IconButton(
                      tooltip: '阅读设置',
                      icon: Icon(Icons.tune, color: palette.text),
                      onPressed: _openSettings,
                    ),
                    IconButton(
                      tooltip: '目录',
                      icon: Icon(Icons.list, color: palette.text),
                      onPressed: _openCatalog,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(ReadPalette palette, ReadPrefs prefs,
      {required bool visible}) {
    final bool lastChapter = _index >= widget.chapters.length - 1;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 1),
          duration: kMotionMid,
          curve: kMotionCurve,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: kMotionFast,
            child: Material(
              color: palette.background,
              elevation: 6,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: prefs.scrollMode
                          ? <Widget>[
                              _barButton(Icons.skip_previous, '上一章', palette,
                                  () => _goChapter(_index - 1), _index > 0),
                              _barButton(Icons.tune, '设置', palette,
                                  _openSettings, true),
                              _barButton(
                                  Icons.list, '目录', palette, _openCatalog, true),
                              _barButton(Icons.skip_next, '下一章', palette,
                                  () => _goChapter(_index + 1), !lastChapter),
                            ]
                          : <Widget>[
                              _barButton(Icons.skip_previous, '上一章', palette,
                                  () => _goChapter(_index - 1), _index > 0),
                              _barButton(Icons.chevron_left, '上一页', palette,
                                  _prevPage, _page > 0 || _index > 0),
                              _barButton(
                                  Icons.list, '目录', palette, _openCatalog, true),
                              _barButton(
                                  Icons.chevron_right,
                                  '下一页',
                                  palette,
                                  _nextPage,
                                  _page < _pages.length - 1 || !lastChapter),
                              _barButton(Icons.skip_next, '下一章', palette,
                                  () => _goChapter(_index + 1), !lastChapter),
                            ],
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _barButton(IconData icon, String label, ReadPalette palette,
      VoidCallback onTap, bool enabled) {
    return Expanded(
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: <Widget>[
              Icon(icon,
                  size: 22,
                  color: enabled ? palette.text : palette.muted.withValues(alpha: 0.5)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: enabled ? palette.muted : palette.muted.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    final AppState state = context.read<AppState>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext c) {
        return StatefulBuilder(
          builder: (BuildContext c, void Function(void Function()) setSheet) {
            final ReadPrefs p = state.prefs;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Text('字号'),
                        Expanded(
                          child: Slider(
                            value: p.fontSize,
                            min: 14,
                            max: 30,
                            divisions: 16,
                            label: p.fontSize.round().toString(),
                            onChanged: (double v) {
                              p.fontSize = v;
                              setSheet(() {});
                              state.updatePrefs(p);
                            },
                          ),
                        ),
                        SizedBox(
                          width: 32,
                          child: Text('${p.fontSize.round()}'),
                        ),
                      ],
                    ),
                    Row(
                      children: <Widget>[
                        const Text('行距'),
                        Expanded(
                          child: Slider(
                            value: p.lineHeight,
                            min: 1.3,
                            max: 2.4,
                            divisions: 11,
                            label: p.lineHeight.toStringAsFixed(1),
                            onChanged: (double v) {
                              p.lineHeight = v;
                              setSheet(() {});
                              state.updatePrefs(p);
                            },
                          ),
                        ),
                        SizedBox(
                          width: 32,
                          child: Text(p.lineHeight.toStringAsFixed(1)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('字体'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: <Widget>[
                        for (final ReaderFont f in ReaderFont.all)
                          ChoiceChip(
                            label: Text(
                              f.label,
                              style: f.apply(fontSize: 14, lineHeight: 1.2),
                            ),
                            selected: p.fontId == f.id,
                            onSelected: (bool v) {
                              p.fontId = f.id;
                              setSheet(() {});
                              state.updatePrefs(p);
                              setState(() {});
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('翻页方式'),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        ChoiceChip(
                          label: const Text('上下滚动'),
                          selected: p.scrollMode,
                          onSelected: (bool v) {
                            p.scrollMode = true;
                            setSheet(() {});
                            state.updatePrefs(p);
                            setState(() {});
                          },
                        ),
                        const SizedBox(width: 10),
                        ChoiceChip(
                          label: const Text('左右翻页'),
                          selected: !p.scrollMode,
                          onSelected: (bool v) {
                            p.scrollMode = false;
                            setSheet(() {});
                            state.updatePrefs(p);
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      p.scrollMode
                          ? '上下滑动阅读；左右滑动翻一屏，滑到头会切上一章/下一章'
                          : '左右滑动或点击屏幕两侧翻页；翻到本章末页自动接下一章',
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: ReadPalette.all[
                                  p.theme.clamp(0, ReadPalette.all.length - 1)]
                              .muted),
                    ),
                    const SizedBox(height: 16),
                    const Text('背景'),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        for (int i = 0; i < ReadPalette.all.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: InkWell(
                              onTap: () {
                                p.theme = i;
                                setSheet(() {});
                                state.updatePrefs(p);
                              },
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: ReadPalette.all[i].background,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: p.theme == i
                                        ? Theme.of(c).colorScheme.primary
                                        : Colors.black12,
                                    width: p.theme == i ? 2 : 1,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '文',
                                  style: TextStyle(
                                      color: ReadPalette.all[i].text,
                                      fontSize: 14),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ChapterHeader extends StatelessWidget {
  const _ChapterHeader({
    required this.title,
    required this.palette,
    required this.fontSize,
  });

  final String title;
  final ReadPalette palette;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: palette.muted,
          fontSize: fontSize * 0.72,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _FooterBar extends StatelessWidget {
  const _FooterBar({
    required this.label,
    required this.index,
    required this.count,
    required this.palette,
  });

  final String label;
  final int index;
  final int count;
  final ReadPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
      child: Row(
        children: <Widget>[
          Text(
            '${index + 1}/$count 章',
            style: TextStyle(color: palette.muted, fontSize: 11),
          ),
          const Spacer(),
          Text(
            label,
            style: TextStyle(color: palette.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.palette,
    required this.onRetry,
    this.onSwitch,
  });

  final String message;
  final ReadPalette palette;
  final VoidCallback onRetry;

  /// 回详情页换个源（这本书在当前源上读不出来时最有用）。
  final VoidCallback? onSwitch;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline, size: 40, color: palette.muted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.text, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              alignment: WrapAlignment.center,
              children: <Widget>[
                OutlinedButton(onPressed: onRetry, child: const Text('重试')),
                if (onSwitch != null)
                  FilledButton(onPressed: onSwitch, child: const Text('换个源')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
