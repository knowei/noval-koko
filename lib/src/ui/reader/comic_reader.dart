import 'package:flutter/material.dart';

import '../../core/text_util.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../model/book_info.dart';
import '../../model/shelf_book.dart';
import '../chapter_list_page.dart';
import '../motion.dart';
import 'read_theme.dart';

/// 漫画阅读器：竖向滚动。
class ComicReaderPage extends StatefulWidget {
  const ComicReaderPage({
    super.key,
    required this.book,
    required this.chapters,
    required this.index,
  });

  final ShelfBook book;
  final List<BookChapter> chapters;
  final int index;

  @override
  State<ComicReaderPage> createState() => _ComicReaderPageState();
}

class _ComicReaderPageState extends State<ComicReaderPage> {
  final Map<int, List<String>> _cache = <int, List<String>>{};
  final ScrollController _scroll = ScrollController();

  late int _index = widget.index;
  List<String> _images = const <String>[];
  bool _loading = true;
  /// 拉图时要带的 Referer（书源域名）。mangabz 这类图床不带就 403。
  String _referer = '';
  String? _error;
  bool _barVisible = false;
  int _percent = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      final double max = _scroll.position.maxScrollExtent;
      final int p = max <= 0
          ? 100
          : ((_scroll.offset / max) * 100).clamp(0, 100).toInt();
      if (p != _percent) setState(() => _percent = p);
    });
    _load(_index);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  BookChapter? get _chapter =>
      _index >= 0 && _index < widget.chapters.length
          ? widget.chapters[_index]
          : null;

  Future<void> _load(int index) async {
    final BookChapter? chapter =
        index >= 0 && index < widget.chapters.length ? widget.chapters[index] : null;
    if (chapter == null) return;

    setState(() {
      _loading = true;
      _error = null;
      _images = const <String>[];
      _percent = 0;
    });

    final List<String>? cached = _cache[index];
    if (cached != null) {
      setState(() {
        _images = cached;
        _loading = false;
      });
      _jumpTop();
      return;
    }

    try {
      final dynamic content =
          await context.read<AppState>().loadContent(widget.book, chapter);
      final List<String> imgs = (content.images as List<String>)
          .map((String u) => _absolute(u, chapter.url))
          .where((String u) => u.isNotEmpty)
          .toList();
      _referer = (content.referer as String?) ?? '';
      _cache[index] = imgs;
      if (!mounted) return;
      setState(() {
        _images = imgs;
        _loading = false;
      });
      _jumpTop();
      await context.read<AppState>().saveProgress(widget.book, index);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _jumpTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  String _absolute(String url, String base) {
    final String u = url.trim();
    if (u.isEmpty) return '';
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    if (u.startsWith('//')) return 'https:$u';
    try {
      return Uri.parse(base).resolve(u).toString();
    } catch (_) {
      return u;
    }
  }

  void _goChapter(int index) {
    if (index < 0 || index >= widget.chapters.length) {
      _toast('已经到头了');
      return;
    }
    setState(() => _index = index);
    _load(index);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 900),
      ));
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

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette =
        ReadPalette.all[context.watch<AppState>().prefs.theme.clamp(
              0,
              ReadPalette.all.length - 1,
            )];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: FadeSwitch(
              child: KeyedSubtree(
                key: ValueKey<int>(_index),
                child: _buildBody(),
              ),
            ),
          ),
          if (_barVisible) _topBar(palette),
          if (_barVisible) _bottomBar(palette),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white70));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline, color: Colors.white54, size: 40),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => _load(_index),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    if (_images.isEmpty) {
      return const Center(
        child: Text('本章没有图片', style: TextStyle(color: Colors.white54)),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _barVisible = !_barVisible),
      child: ListView.builder(
        controller: _scroll,
        padding: EdgeInsets.zero,
        itemCount: _images.length + 1,
        itemBuilder: (BuildContext context, int i) {
          if (i == _images.length) return _endTile();
          return _ComicImage(url: _images[i], referer: _referer);
        },
      ),
    );
  }

  Widget _endTile() {
    final bool hasNext = _index < widget.chapters.length - 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: <Widget>[
          Text(
            '本章完 · ${_chapter?.title ?? ''}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (hasNext)
            FilledButton(
              onPressed: () => _goChapter(_index + 1),
              child: const Text('下一章'),
            )
          else
            const Text('已经是最后一章',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _topBar(ReadPalette palette) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.black.withValues(alpha: 0.82),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.book.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                    Text(
                      _chapter?.title ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '目录',
                icon: const Icon(Icons.list, color: Colors.white),
                onPressed: _openCatalog,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(ReadPalette palette) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Material(
        color: Colors.black.withValues(alpha: 0.82),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Row(
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.skip_previous, color: Colors.white),
                  onPressed: () => _goChapter(_index - 1),
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '$_percent%  ·  ${_index + 1}/${widget.chapters.length}',
                        style:
                            const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: _percent / 100,
                        minHeight: 2,
                        backgroundColor: Colors.white24,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next, color: Colors.white),
                  onPressed: () => _goChapter(_index + 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComicImage extends StatefulWidget {
  const _ComicImage({required this.url, this.referer});

  final String url;
  final String? referer;

  @override
  State<_ComicImage> createState() => _ComicImageState();
}

class _ComicImageState extends State<_ComicImage> {
  /// 图床镜像下标：这张图失败了就换镜像域名再试一次。
  int _mirror = 0;

  @override
  void didUpdateWidget(covariant _ComicImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _mirror = 0;
  }

  void _tryNextMirror(List<String> variants) {
    if (_mirror + 1 >= variants.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _mirror += 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<String> variants = TextUtil.imageUrlVariants(widget.url);
    final String url = variants[_mirror.clamp(0, variants.length - 1)];
    return Image.network(
      url,
      headers: TextUtil.imageHeaders(url, referer: widget.referer),
      width: double.infinity,
      fit: BoxFit.fitWidth,
      // 图片从上方淡入，避免长图一屏屏「弹」出来
      frameBuilder: (
        BuildContext context,
        Widget child,
        int? frame,
        bool wasSynchronouslyLoaded,
      ) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: kMotionSlow,
          curve: kMotionCurve,
          child: child,
        );
      },
      loadingBuilder: (
        BuildContext context,
        Widget child,
        ImageChunkEvent? progress,
      ) {
        if (progress == null) return child;
        final double? total = progress.expectedTotalBytes?.toDouble();
        return SizedBox(
          height: 220,
          child: Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white38,
                value: total == null || total == 0
                    ? null
                    : progress.cumulativeBytesLoaded / total,
              ),
            ),
          ),
        );
      },
      errorBuilder:
          (BuildContext context, Object error, StackTrace? stackTrace) {
        _tryNextMirror(variants);
        return Container(
          height: 160,
          alignment: Alignment.center,
          color: const Color(0xFF1A1A1A),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.broken_image_outlined, color: Colors.white24),
              SizedBox(height: 6),
              Text('图片加载失败', style: TextStyle(color: Colors.white24, fontSize: 11)),
            ],
          ),
        );
      },
    );
  }
}
