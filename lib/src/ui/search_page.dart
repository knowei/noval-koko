import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../model/search_book.dart';
import '../model/shelf_book.dart';
import 'book_detail_page.dart';
import 'motion.dart';
import 'theme/app_theme.dart';
import 'widgets.dart';

/// 搜索：把所有书源的结果**平铺**成一个列表，每条后面标出来源。
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final List<SearchOutcome> _outcomes = <SearchOutcome>[];
  bool _loading = false;
  String _keyword = '';
  String _sourceFilter = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final AppState state = context.read<AppState>();
    final String key = _controller.text.trim();
    if (key.isEmpty) return;
    if (state.searchableSources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('还没有可用的书源，请先在「书源」里导入')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _keyword = key;
      _sourceFilter = '';
      _outcomes.clear();
    });

    await state.searchAll(key, onOutcome: (SearchOutcome o) {
      if (!mounted) return;
      setState(() => _outcomes.add(o));
    });

    if (mounted) setState(() => _loading = false);
  }

  /// 把「按源分组的批次」摊平成一串 (书, 源名)。
  ///
  /// 这里**按源轮转**取，而不是一个源整批倒完：某个源动辄吐出几十条
  /// （比如河豚小说搜「斗破苍穹」有 68 条），一旦整批排在前面，
  /// 别的源的条目就被挤到很后面，看起来像「只有这个源有结果」。
  List<_Flat> get _flat {
    final List<SearchOutcome> groups = _outcomes
        .where((SearchOutcome o) =>
            _sourceFilter.isEmpty || o.sourceUrl == _sourceFilter)
        .where((SearchOutcome o) => o.books.isNotEmpty)
        .toList();
    final List<_Flat> out = <_Flat>[];
    for (int i = 0;; i++) {
      bool any = false;
      for (final SearchOutcome o in groups) {
        if (i >= o.books.length) continue;
        out.add(_Flat(o.books[i], o.sourceName, _keyword));
        any = true;
      }
      if (!any) break;
    }
    return out;
  }

  List<SearchOutcome> get _failed =>
      _outcomes.where((SearchOutcome o) => !o.ok).toList();

  /// 空结果时说清「谁查过、谁没收录」，避免看起来像书源挂了。
  String get _emptyDetail {
    if (_keyword.isEmpty) {
      return '同一本书可能来自多个书源，结果后面会标出来源';
    }
    if (_loading || _outcomes.isEmpty) {
      return '还没有书源返回结果';
    }
    final List<String> zeros = _outcomes
        .where((SearchOutcome o) => o.ok && o.books.isEmpty)
        .map((SearchOutcome o) => o.sourceName)
        .toList();
    if (zeros.isNotEmpty) {
      return '${zeros.length} 个源查过但没收录：${zeros.join(' · ')}';
    }
    if (_failed.isNotEmpty) {
      return '${_failed.length} 个源出错，点上面的红条看原因';
    }
    return '换个关键词，或换个书源试试';
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final AppState state = context.watch<AppState>();
    final List<_Flat> rows = _flat;
    final int total = state.searchableSources.length;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            PageHeader(
              title: '搜索',
              subtitle: _keyword.isEmpty
                  ? '$total 个书源可用'
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.page, 0, AppSpace.page, AppSpace.md),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                style: TextStyle(fontSize: 15, color: p.ink),
                decoration: InputDecoration(
                  hintText: '书名 / 作者',
                  prefixIcon: Icon(Icons.search, size: 20, color: p.inkMid),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(Icons.close,
                              size: 18, color: p.inkFaint),
                          onPressed: () {
                            _controller.clear();
                            setState(() {});
                          },
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (_keyword.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.page, 0, AppSpace.page, AppSpace.sm),
                child: Row(
                  children: <Widget>[
                    Text(
                      '搜索结果 · ${rows.length} 条',
                      style: context.text.bodySmall,
                    ),
                    const Spacer(),
                    if (_loading)
                      GestureDetector(
                        onTap: () =>
                            context.read<AppState>().cancelSearch(),
                        child: Text('停止', style: context.text.bodySmall),
                      )
                    else
                      _SourceFilterChip(
                        label: _sourceFilter.isEmpty
                            ? '全部书源'
                            : (_outcomes.firstWhere(
                                  (SearchOutcome o) =>
                                      o.sourceUrl == _sourceFilter,
                                ).sourceName),
                        onPick: (String? url) =>
                            setState(() => _sourceFilter = url ?? ''),
                        outcomes: _outcomes,
                      ),
                  ],
                ),
              ),
            if (_loading)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.page),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: AppRadius.rPill,
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        backgroundColor: p.surfaceAlt,
                        value: total == 0
                            ? null
                            : (_outcomes.length / total).clamp(0.0, 1.0),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('已搜 ${_outcomes.length} / $total 源',
                        style: context.text.bodySmall),
                  ],
                ),
              ),
            if (_failed.isNotEmpty && !_loading)
              _FailedBar(failed: _failed),
            Expanded(
              child: rows.isEmpty
                  ? EmptyHint(
                      icon: Icons.travel_explore,
                      title: _loading
                          ? '正在搜索…'
                          : (_keyword.isEmpty ? '输入书名开始搜索' : '没有找到「$_keyword」'),
                      subtitle: _loading ? '结果会边搜边出来' : _emptyDetail,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpace.page, AppSpace.xs, AppSpace.page, 96),
                      itemCount: rows.length,
                      separatorBuilder: (BuildContext c, int i) => Divider(
                        height: 1,
                        thickness: 1,
                        color: p.line,
                        indent: 68,
                      ),
                      itemBuilder: (BuildContext context, int i) => FadeSlideIn(
                        index: i,
                        rise: 8,
                        child: _ResultRow(flat: rows[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Flat {
  const _Flat(this.book, this.sourceName, this.keyword);

  final SearchBook book;
  final String sourceName;
  final String keyword;

  /// 站点搜索接口不可靠时（例如按单字模糊匹配），标题里根本不包含关键词。
  bool get exact => keyword.isEmpty || book.name.contains(keyword);
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.flat});

  final _Flat flat;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final SearchBook book = flat.book;

    final ShelfBook draft = ShelfBook(
      bookUrl: book.bookUrl,
      name: book.name,
      author: book.author,
      cover: book.cover,
      intro: book.intro,
      kind: book.kind,
      sourceUrl: book.sourceUrl,
      sourceName: book.sourceName,
      type: book.type,
      latestChapter: book.lastChapter,
    );

    return InkWell(
      onTap: () => Navigator.of(context).push(
        fadeSlideRoute<void>(BookDetailPage(book: draft)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            BookCover(
              url: book.cover,
              name: book.name,
              width: 56,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    book.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      if (book.author.isNotEmpty) ...<Widget>[
                        Flexible(
                          child: Text(
                            book.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodySmall,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      SourceTag(flat.sourceName, type: book.type),
                      if (!flat.exact) ...<Widget>[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '· 站点模糊匹配',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodySmall?.copyWith(
                              color: p.inkFaint,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 18, left: 6),
              child: Icon(Icons.chevron_right, size: 18, color: p.inkFaint),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceFilterChip extends StatelessWidget {
  const _SourceFilterChip({
    required this.label,
    required this.onPick,
    required this.outcomes,
  });

  final String label;
  final ValueChanged<String?> onPick;
  final List<SearchOutcome> outcomes;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;

    return PopupMenuButton<String>(
      tooltip: '按书源筛选',
      onSelected: (String v) => onPick(v.isEmpty ? null : v),
      itemBuilder: (BuildContext c) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(value: '', child: Text('全部书源')),
        for (final SearchOutcome o in outcomes)
          PopupMenuItem<String>(
            value: o.sourceUrl,
            child: Text('${o.sourceName}（${o.books.length}）'),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: AppRadius.rPill,
          border: Border.all(color: p.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(label,
                style: TextStyle(fontSize: 12, color: p.inkMid)),
            Icon(Icons.arrow_drop_down, size: 16, color: p.inkFaint),
          ],
        ),
      ),
    );
  }
}

class _FailedBar extends StatelessWidget {
  const _FailedBar({required this.failed});

  final List<SearchOutcome> failed;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.page, 0, AppSpace.page, AppSpace.xs),
      child: InkWell(
        borderRadius: AppRadius.rSm,
        onTap: () => showDialog<void>(
          context: context,
          builder: (BuildContext c) => AlertDialog(
            title: Text('${failed.length} 个书源失败'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final SearchOutcome o in failed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${o.sourceName}：${o.error ?? '未知错误'}',
                        style: context.text.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(c).pop(),
                child: const Text('知道了'),
              ),
            ],
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.error_outline, size: 14, color: p.bad),
            const SizedBox(width: 6),
            Text('${failed.length} 个源失败',
                style: TextStyle(fontSize: 12, color: p.bad)),
            Icon(Icons.chevron_right, size: 14, color: p.bad),
          ],
        ),
      ),
    );
  }
}
