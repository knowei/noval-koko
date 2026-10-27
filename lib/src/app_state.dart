import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'core/html_text.dart';
import 'db/database.dart';
import 'db/shelf_repo.dart';
import 'db/source_repo.dart';
import 'local/local_book_store.dart';
import 'model/book_info.dart';
import 'model/book_source.dart';
import 'model/search_book.dart';
import 'model/shelf_book.dart';
import 'source/source_engine.dart';
import 'ui/theme/app_theme.dart';

/// 一次「按书源」的搜索结果。
class SearchOutcome {
  SearchOutcome({
    required this.sourceName,
    required this.sourceUrl,
    this.books = const <SearchBook>[],
    this.error,
    this.costMs = 0,
  });

  final String sourceName;
  final String sourceUrl;
  final List<SearchBook> books;
  final String? error;
  final int costMs;

  bool get ok => error == null;
}

/// 阅读器的阅读偏好。
class ReadPrefs {
  ReadPrefs({
    this.fontSize = 19,
    this.lineHeight = 1.7,
    this.theme = 0,
    this.padding = 18,
    this.scrollMode = true,
  });

  double fontSize;
  double lineHeight;
  int theme; // 0 纸黄 1 白 2 夜间 3 护眼绿
  double padding;

  /// true=上下滚动，false=左右翻页。
  bool scrollMode;

  Map<String, Object?> toJson() => <String, Object?>{
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'theme': theme,
        'padding': padding,
        'scrollMode': scrollMode,
      };

  static ReadPrefs fromJson(Map<String, dynamic> j) => ReadPrefs(
        fontSize: (j['fontSize'] as num?)?.toDouble() ?? 19,
        lineHeight: (j['lineHeight'] as num?)?.toDouble() ?? 1.7,
        theme: (j['theme'] as int?) ?? 0,
        padding: (j['padding'] as num?)?.toDouble() ?? 18,
        scrollMode: (j['scrollMode'] as bool?) ?? true,
      );
}

/// 全局状态。UI 只通过它拿数据和动作。
class AppState extends ChangeNotifier {
  AppState();

  late final ShelfRepo shelfRepo;
  late final SourceRepo sourceRepo;
  late final SourceEngine engine;

  List<BookSource> sources = <BookSource>[];
  List<ShelfBook> shelf = <ShelfBook>[];
  ReadPrefs prefs = ReadPrefs();

  /// 当前主题 id（见 [kAppThemes]）。
  String themeId = kMotimg.id;
  AppTheme get theme => themeById(themeId);

  bool ready = false;
  bool searching = false;
  bool _cancelSearch = false;

  Future<void> bootstrap() async {
    await AppDatabase.instance.init();
    shelfRepo = ShelfRepo();
    sourceRepo = SourceRepo();
    engine = SourceEngine();
    await _attachCookieStore();

    await reloadSources();
    await reloadShelf();

    final String? prefsJson = await shelfRepo.getSetting('read_prefs');
    if (prefsJson != null && prefsJson.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(prefsJson);
        if (decoded is Map<String, dynamic>) prefs = ReadPrefs.fromJson(decoded);
      } catch (_) {}
    }
    final String? savedTheme = await shelfRepo.getSetting('app_theme');
    if (savedTheme != null && savedTheme.isNotEmpty) themeId = themeById(savedTheme).id;
    ready = true;
    notifyListeners();
  }

  /// Cookie 存磁盘：cf_clearance、登录态这类东西拿一次就够了，
  /// 存下来下次启动直接复用，不用再让人去浏览器里重新过验证。
  Timer? _cookieTimer;

  Future<void> _attachCookieStore() async {
    try {
      final Directory dir = await getApplicationSupportDirectory();
      engine.http.cookieFile = '${dir.path}/cookies.json';
      await engine.http.loadCookies();
      engine.http.onCookiesChanged = () {
        _cookieTimer?.cancel();
        _cookieTimer = Timer(const Duration(seconds: 3), () {
          engine.http.saveCookies();
        });
      };
    } on Object {
      // 拿不到目录就退化成纯内存 Cookie，不影响功能。
    }
  }

  Future<void> reloadSources() async {
    sources = await sourceRepo.all();
    notifyListeners();
  }

  Future<void> reloadShelf() async {
    shelf = await shelfRepo.all();
    notifyListeners();
  }

  List<BookSource> get enabledSources =>
      sources.where((BookSource s) => s.enabled).toList();

  List<BookSource> get searchableSources => sources
      .where((BookSource s) => s.enabled && s.canSearch)
      .toList();

  BookSource? sourceOf(String url) {
    for (final BookSource s in sources) {
      if (s.url == url) return s;
    }
    return null;
  }

  // ---------------------------------------------------------------- sources

  Future<int> importText(String text) async {
    final List<BookSource> parsed = SourceRepo.parseSources(text);
    if (parsed.isEmpty) {
      throw const FormatException('没有识别到有效的书源 JSON');
    }
    final int n = await sourceRepo.saveAll(parsed);
    await reloadSources();
    return n;
  }

  Future<void> setSourceEnabled(BookSource source, bool enabled) async {
    await sourceRepo.setEnabled(source.url, enabled);
    await reloadSources();
  }

  Future<void> deleteSources(List<String> urls) async {
    await sourceRepo.remove(urls);
    await reloadSources();
  }

  Future<String> exportSources({bool enabledOnly = false}) =>
      sourceRepo.exportAll(enabledOnly: enabledOnly);

  // ----------------------------------------------------------------- search

  void cancelSearch() {
    _cancelSearch = true;
    searching = false;
    notifyListeners();
  }

  /// 顺序搜索所有可用书源，每完成一个就回调，UI 可以边搜边显示。
  Future<void> searchAll(
    String key, {
    required void Function(SearchOutcome outcome) onOutcome,
  }) async {
    _cancelSearch = false;
    searching = true;
    notifyListeners();

    final List<BookSource> list = searchableSources;
    for (final BookSource source in list) {
      if (_cancelSearch) break;
      final int start = DateTime.now().millisecondsSinceEpoch;
      try {
        final List<SearchBook> books =
            await engine.search(source, key).timeout(const Duration(seconds: 25));
        onOutcome(SearchOutcome(
          sourceName: source.name,
          sourceUrl: source.url,
          books: books,
          costMs: DateTime.now().millisecondsSinceEpoch - start,
        ));
      } catch (e) {
        onOutcome(SearchOutcome(
          sourceName: source.name,
          sourceUrl: source.url,
          error: _friendly(e),
          costMs: DateTime.now().millisecondsSinceEpoch - start,
        ));
      }
    }

    searching = false;
    notifyListeners();
  }

  String _friendly(Object e) {
    final String s = e.toString();
    if (s.contains('SocketException') || s.contains('Failed host lookup')) {
      return '网络不可用';
    }
    if (s.contains('TimeoutException')) return '超时';
    return s.length > 120 ? '${s.substring(0, 120)}…' : s;
  }

  // ------------------------------------------------------------------ books

  Future<List<BookChapter>> loadChapters(
    ShelfBook book, {
    bool refresh = false,
  }) async {
    if (!refresh) {
      final List<BookChapter> cached = await shelfRepo.chapters(book.bookUrl);
      if (cached.isNotEmpty) return cached;
    }
    if (LocalBookStore.isLocalUrl(book.bookUrl)) {
      final List<BookChapter> chapters =
          await LocalBookStore.instance.chapters(book);
      await shelfRepo.saveChapters(book.bookUrl, chapters);
      book.totalChapters = chapters.length;
      if (chapters.isNotEmpty) book.latestChapter = chapters.last.title;
      await shelfRepo.upsert(book);
      return chapters;
    }
    final BookSource? source = sourceOf(book.sourceUrl);
    if (source == null) {
      throw StateError('这本书所属的书源已被删除：${book.sourceName}');
    }
    engine.resetJs();
    final BookInfo info = await engine.bookInfo(
      source,
      book.bookUrl,
      fallbackName: book.name,
      fallbackAuthor: book.author,
      fallbackIntro: book.intro,
      fallbackCover: book.cover,
    );
    final List<BookChapter> chapters = await engine.chapters(source, info);
    await shelfRepo.saveChapters(book.bookUrl, chapters);
    book.totalChapters = chapters.length;
    if (chapters.isNotEmpty) book.latestChapter = chapters.last.title;
    // 搜索页的 coverUrl 常常是空的，详情页才有；顺手把书架里的元数据补全，
    // 否则书架/详情页永远只有首字占位图。
    bool metaChanged = false;
    if (book.cover.trim().isEmpty && info.cover.trim().isNotEmpty) {
      book.cover = info.cover.trim();
      metaChanged = true;
    }
    if (book.author.trim().isEmpty && info.author.trim().isNotEmpty) {
      book.author = info.author.trim();
      metaChanged = true;
    }
    if (book.intro.trim().isEmpty && info.intro.trim().isNotEmpty) {
      book.intro = info.intro.trim();
      metaChanged = true;
    }
    await shelfRepo.upsert(book);
    if (metaChanged) await reloadShelf();
    return chapters;
  }

  /// 书架下拉刷新：把「封面 / 作者 / 简介 / 章节数」缺的补齐。
  ///
  /// 之前入架的书是按老规则搜出来的，封面字段是空的；这里重新走一遍详情页
  /// 把元数据填回去。单个失败不影响其它书（站点随时会挂）。
  Future<int> refreshShelfMeta() async {
    int fixed = 0;
    for (final ShelfBook book in List<ShelfBook>.of(shelf)) {
      if (LocalBookStore.isLocalUrl(book.bookUrl)) continue;
      final bool needMeta = book.cover.trim().isEmpty ||
          book.author.trim().isEmpty ||
          book.intro.trim().isEmpty;
      final bool needToc = book.totalChapters <= 0;
      if (!needMeta && !needToc) continue;
      final BookSource? source = sourceOf(book.sourceUrl);
      if (source == null) continue;
      try {
        engine.resetJs();
        final BookInfo info = await engine.bookInfo(
          source,
          book.bookUrl,
          fallbackName: book.name,
          fallbackAuthor: book.author,
          fallbackIntro: book.intro,
          fallbackCover: book.cover,
        );
        bool changed = false;
        if (book.cover.trim().isEmpty && info.cover.trim().isNotEmpty) {
          book.cover = info.cover.trim();
          changed = true;
        }
        if (book.author.trim().isEmpty && info.author.trim().isNotEmpty) {
          book.author = info.author.trim();
          changed = true;
        }
        if (book.intro.trim().isEmpty && info.intro.trim().isNotEmpty) {
          book.intro = info.intro.trim();
          changed = true;
        }
        if (needToc) {
          final List<BookChapter> chapters = await engine.chapters(source, info);
          if (chapters.isNotEmpty) {
            await shelfRepo.saveChapters(book.bookUrl, chapters);
            book.totalChapters = chapters.length;
            book.latestChapter = chapters.last.title;
            changed = true;
          }
        }
        if (changed) {
          await shelfRepo.upsert(book);
          fixed++;
        }
      } catch (_) {
        // 单个源/单本书失败就跳过，下次下拉再试
      }
    }
    await reloadShelf();
    return fixed;
  }

  Future<BookContent> loadContent(
    ShelfBook book,
    BookChapter chapter,
  ) async {
    if (LocalBookStore.isLocalUrl(book.bookUrl)) {
      return LocalBookStore.instance.content(book, chapter);
    }
    final BookSource? source = sourceOf(book.sourceUrl);
    if (source == null) {
      throw StateError('这本书所属的书源已被删除：${book.sourceName}');
    }
    final BookContent raw = await engine.content(source, chapter);
    // 书源的 @html 规则拿到的是带标签的 HTML；在这里一次性拍平成纯文本，
    // 阅读器/预览/TTS 拿到的都是干净文本。
    return BookContent(
      text: raw.text.isEmpty ? raw.text : htmlToPlainText(raw.text),
      images: raw.images,
      nextUrl: raw.nextUrl,
      title: raw.title,
    );
  }

  Future<void> addToShelf(ShelfBook book) async {
    await shelfRepo.upsert(book);
    await reloadShelf();
  }

  Future<bool> inShelf(String bookUrl) async =>
      (await shelfRepo.find(bookUrl)) != null;

  /// 导入本地 TXT / EPUB：复制进应用目录、切章入库、直接上书架。
  /// 单个文件失败不影响其它文件，失败原因在返回值里。
  Future<List<LocalImportResult>> importLocalBooks(List<String> paths) async {
    final List<LocalImportResult> results =
        await LocalBookStore.instance.importFiles(paths);
    for (final LocalImportResult r in results) {
      if (!r.ok) continue;
      await shelfRepo.upsert(r.book);
      await shelfRepo.saveChapters(r.book.bookUrl, r.chapters);
    }
    await reloadShelf();
    return results;
  }

  Future<void> removeFromShelf(String bookUrl) async {
    await shelfRepo.remove(bookUrl);
    await reloadShelf();
  }

  Future<void> saveProgress(ShelfBook book, int index, {double offset = 0}) async {
    await shelfRepo.saveProgress(
        bookUrl: book.bookUrl, index: index, offset: offset);
  }

  // ------------------------------------------------------------------ prefs

  Future<void> updatePrefs(ReadPrefs next) async {
    prefs = next;
    notifyListeners();
    await shelfRepo.setSetting('read_prefs', _encodePrefs(next));
  }

  /// 切换整体主题（颜色 + 组件样式），立即生效并持久化。
  Future<void> setTheme(String id) async {
    final AppTheme next = themeById(id);
    if (next.id == themeId) return;
    themeId = next.id;
    notifyListeners();
    await shelfRepo.setSetting('app_theme', next.id);
  }

  String _encodePrefs(ReadPrefs p) => jsonEncode(p.toJson());

  @override
  void dispose() {
    if (ready) engine.dispose();
    super.dispose();
  }
}
