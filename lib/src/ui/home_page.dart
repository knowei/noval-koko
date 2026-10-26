import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../local/local_book_store.dart';
import '../model/shelf_book.dart';
import 'book_detail_page.dart';
import 'motion.dart';
import 'theme/app_theme.dart';
import 'theme/theme_sheet.dart';
import 'widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _filter = 0; // 0 全部 1 小说 2 漫画 3 追更

  List<ShelfBook> _filtered(List<ShelfBook> all) {
    switch (_filter) {
      case 1:
        return all.where((ShelfBook b) => !b.isComic).toList();
      case 2:
        return all.where((ShelfBook b) => b.isComic).toList();
      case 3:
        return all
            .where((ShelfBook b) =>
                b.totalChapters > 0 && b.lastReadIndex < b.totalChapters - 1)
            .toList();
      default:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final List<ShelfBook> shelf = state.shelf;
    final List<ShelfBook> list = _filtered(shelf);

    ShelfBook? current;
    for (final ShelfBook b in shelf) {
      if (b.lastReadTime <= 0) continue;
      if (current == null || b.lastReadTime > current.lastReadTime) current = b;
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _refreshMeta(context),
          color: context.palette.primary,
          child: CustomScrollView(
            // 即使内容不足一屏也允许下拉（否则书少时拉不动）
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: PageHeader(
                  title: '书架',
                  subtitle: shelf.isEmpty
                      ? '还没有书'
                      : '${shelf.length} 本 · ${_updatingCount(shelf)} 本追更中',
                  actions: <Widget>[
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _importLocal(context),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(Icons.add_circle_outline,
                            size: 22, color: context.palette.ink),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _refreshMeta(context),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(Icons.refresh,
                            size: 22, color: context.palette.ink),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _pickTheme(context),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(Icons.palette_outlined,
                            size: 22, color: context.palette.ink),
                      ),
                    ),
                  ],
                ),
              ),
              if (current != null)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SectionHeader(
                        title: '继续阅读',
                        onTap: () => _open(context, current!),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.page),
                        child: FadeSlideIn(
                          child: _ContinueCard(
                            book: current,
                            onTap: () => _open(context, current!),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.page, AppSpace.lg, AppSpace.page, 0),
                  child: Row(
                    children: <Widget>[
                      for (int i = 0; i < 4; i++) ...<Widget>[
                        AppChip(
                          label: const <String>['全部', '小说', '漫画', '追更'][i],
                          selected: _filter == i,
                          onTap: () => setState(() => _filter = i),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ),
              if (list.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyHint(
                    icon: Icons.auto_stories_outlined,
                    title: shelf.isEmpty ? '书架还是空的' : '这里还没有书',
                    subtitle: shelf.isEmpty
                        ? '右上角 + 导入本地 TXT / EPUB，或去「书源」导入规则后到「搜索」找书'
                        : '换个筛选条件试试',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.page, AppSpace.lg, AppSpace.page, 96),
                  sliver: _grid(context, list),
                ),
            ],
          ),
        ),
      ),
    );
  }

  int _updatingCount(List<ShelfBook> all) => all
      .where((ShelfBook b) =>
          b.totalChapters > 0 && b.lastReadIndex < b.totalChapters - 1)
      .length;

  Widget _grid(BuildContext context, List<ShelfBook> list) {
    final double w = MediaQuery.sizeOf(context).width - AppSpace.page * 2;
    final int cols = (w / 116).floor().clamp(3, 6);
    final double gap = 14;
    final double itemW = (w - gap * (cols - 1)) / cols;

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: gap,
        mainAxisSpacing: 18,
        mainAxisExtent: itemW * 4 / 3 + 72,
      ),
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int i) => FadeSlideIn(
          index: i,
          child: _ShelfTile(book: list[i]),
        ),
        childCount: list.length,
      ),
    );
  }

  void _open(BuildContext context, ShelfBook book) {
    Navigator.of(context).push(
      fadeSlideRoute<void>(BookDetailPage(book: book)),
    );
  }

  /// 补全书架上缺的封面 / 作者 / 总章数（老数据、或源当时没解析出来）。
  Future<void> _refreshMeta(BuildContext context) async {
    final AppState state = context.read<AppState>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final int fixed = await state.refreshShelfMeta();
      messenger.showSnackBar(
        SnackBar(
          content: Text(fixed > 0 ? '已补全 $fixed 本书的信息' : '书架信息都是最新的'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('刷新失败：$e')));
    }
  }

  /// 导入本地 TXT / EPUB：不经任何书源，直接上书架。
  Future<void> _importLocal(BuildContext context) async {
    final AppState state = context.read<AppState>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    List<PlatformFile> files;
    try {
      files = await FilePicker.pickFiles(
        dialogTitle: '选择要导入的 TXT / EPUB',
        type: FileType.custom,
        allowedExtensions: <String>['txt', 'epub'],
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('打开文件选择器失败：$e')));
      return;
    }
    final List<String> paths = <String>[
      for (final PlatformFile f in files)
        if (f.path != null) f.path!,
    ];
    if (paths.isEmpty) return;

    messenger.showSnackBar(const SnackBar(content: Text('正在导入…')));
    final List<LocalImportResult> results = await state.importLocalBooks(paths);
    if (!context.mounted) return;
    final List<LocalImportResult> ok =
        results.where((LocalImportResult r) => r.ok).toList();
    final List<LocalImportResult> bad =
        results.where((LocalImportResult r) => !r.ok).toList();
    final String message = bad.isEmpty
        ? '已导入 ${ok.length} 本'
        : '成功 ${ok.length} 本；失败 ${bad.length} 本：'
            '${bad.map((LocalImportResult r) => '${r.book.name}（${r.error}）').join('、')}';
    messenger.showSnackBar(SnackBar(
      content: Text(message),
      duration: Duration(seconds: bad.isEmpty ? 3 : 8),
    ));
  }

  /// 主题切换：以后加主题只要往 [kAppThemes] 里补一条。
  Future<void> _pickTheme(BuildContext context) => showThemeSheet(context);
}

/// 「继续阅读」横卡。
class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.book, required this.onTap});

  final ShelfBook book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final int total = book.totalChapters;
    final double ratio = total <= 0
        ? 0
        : ((book.lastReadIndex + 1) / total).clamp(0.0, 1.0);
    final int percent = (ratio * 100).round();

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          BookCover(url: book.cover, name: book.name, width: 64),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  book.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.headlineSmall?.copyWith(fontSize: 17),
                ),
                const SizedBox(height: 4),
                Text(
                  total <= 0
                      ? '尚未加载目录'
                      : '第 ${(book.lastReadIndex + 1).clamp(1, total)} 章 · ${_ago(book.lastReadTime)}',
                  style: context.text.bodySmall,
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: ClipRRect(
                        borderRadius: AppRadius.rPill,
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 4,
                          backgroundColor: p.surfaceAlt,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$percent%',
                        style: TextStyle(fontSize: 11, color: p.inkMid)),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: p.primary,
                      borderRadius: AppRadius.rPill,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.play_arrow_rounded,
                            size: 16, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          '继续阅读',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _ago(int ms) {
    if (ms <= 0) return '未读';
    final Duration d = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(ms));
    if (d.inMinutes < 1) return '刚刚';
    if (d.inHours < 1) return '${d.inMinutes} 分钟前';
    if (d.inDays < 1) return '${d.inHours} 小时前';
    if (d.inDays < 30) return '${d.inDays} 天前';
    return '${(d.inDays / 30).floor()} 个月前';
  }
}

class _ShelfTile extends StatelessWidget {
  const _ShelfTile({required this.book});

  final ShelfBook book;

  @override
  Widget build(BuildContext context) {
    final int total = book.totalChapters;
    final String badge = total <= 0
        ? ''
        : '${(((book.lastReadIndex + 1) / total) * 100).round()}%';

    return TapScale(
      onTap: () => Navigator.of(context).push(
        fadeSlideRoute<void>(BookDetailPage(book: book)),
      ),
      onLongPress: () => _showMenu(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) => BookCover(
              url: book.cover,
              name: book.name,
              width: c.maxWidth,
              badge: badge.isEmpty ? null : badge,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleSmall,
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
            total > 0
                ? '${book.sourceName} · 共 $total 章'
                : '${book.sourceName} · 未加载目录',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall?.copyWith(fontSize: 11),
          ),
          ),
        ],
      ),
    );
  }

  Future<void> _showMenu(BuildContext context) async {
    final AppState state = context.read<AppState>();
    final String? action = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('书籍详情'),
              onTap: () => Navigator.of(c).pop('info'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('移出书架'),
              onTap: () => Navigator.of(c).pop('delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;

    if (action == 'info') {
      await Navigator.of(context).push(
        fadeSlideRoute<void>(BookDetailPage(book: book)),
      );
    } else if (action == 'delete') {
      final bool? ok = await showDialog<bool>(
        context: context,
        builder: (BuildContext c) => AlertDialog(
          title: const Text('移出书架'),
          content: Text('确定把《${book.name}》移出书架吗？'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      if (ok == true) await state.removeFromShelf(book.bookUrl);
    }
  }
}
