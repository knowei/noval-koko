import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'core/html_text.dart';
import 'core/rule_exception.dart';
import 'core/text_util.dart';
import 'db/database.dart';
import 'db/shelf_repo.dart';
import 'db/source_repo.dart';
import 'local/local_book_store.dart';
import 'net/dns_override.dart';
import 'model/book_info.dart';
import 'model/book_source.dart';
import 'model/search_book.dart';
import 'model/shelf_book.dart';
import 'model/source_subscription.dart';
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
    this.lineHeight = 1.85,
    this.theme = 0,
    this.padding = 18,
    this.scrollMode = true,
    this.fontId = 'song',
  });

  double fontSize;
  double lineHeight;
  int theme; // 0 纸黄 1 白 2 夜间 3 护眼绿
  double padding;

  /// 正文字体：song 宋体 / hei 黑体 / kai 楷体 / system 系统默认。
  String fontId;

  /// true=上下滚动，false=左右翻页。
  bool scrollMode;

  Map<String, Object?> toJson() => <String, Object?>{
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'theme': theme,
        'padding': padding,
        'scrollMode': scrollMode,
        'fontId': fontId,
      };

  static ReadPrefs fromJson(Map<String, dynamic> j) => ReadPrefs(
        fontSize: (j['fontSize'] as num?)?.toDouble() ?? 19,
        lineHeight: (j['lineHeight'] as num?)?.toDouble() ?? 1.85,
        theme: (j['theme'] as int?) ?? 0,
        padding: (j['padding'] as num?)?.toDouble() ?? 18,
        scrollMode: (j['scrollMode'] as bool?) ?? true,
        fontId: (j['fontId'] as String?) ?? 'song',
      );
}

/// 全局状态。UI 只通过它拿数据和动作。
/// 换源候选：另一个源里的同一本书。
class SourceCandidate {
  SourceCandidate({required this.source, required this.book});

  final BookSource source;
  final SearchBook book;
}

/// 换源结果：换成哪个条目、新源的章节目录、迁移后的进度。
class SwitchResult {
  SwitchResult({
    required this.book,
    required this.chapters,
    required this.index,
  });

  final ShelfBook book;
  final List<BookChapter> chapters;
  final int index;
}

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

  /// 主题模式：system 跟随系统 / light 浅色 / dark 深色。
  String themeModeId = 'system';

  /// 哔咔登录后的昵称；空 = 没登录（或还没拉到）。
  String picaUserName = '';

  ThemeMode get themeMode => switch (themeModeId) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  bool ready = false;
  bool searching = false;
  bool _cancelSearch = false;

  Future<void> bootstrap() async {
    await AppDatabase.instance.init();
    // 先把「域名→真实 IP」覆盖表读进来（内置表 + 数据目录里的
    // dns_overrides.json）。国内 DNS 对被墙站点返回伪造 IP，没有这张表
    // 那些站一律超时；有了真 IP 就能直连（Host/SNI 仍是原域名）。
    try {
      await DnsOverride.loadFromSupportDir(
        await getApplicationSupportDirectory(),
      );
    } catch (_) {}
    shelfRepo = ShelfRepo();
    sourceRepo = SourceRepo();
    engine = SourceEngine();
    await _attachCookieStore();

    await reloadSources();
    await reloadShelf();
    await reloadSubscriptions();

    final String? prefsJson = await shelfRepo.getSetting('read_prefs');
    if (prefsJson != null && prefsJson.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(prefsJson);
        if (decoded is Map<String, dynamic>) prefs = ReadPrefs.fromJson(decoded);
      } catch (_) {}
    }
    final String? savedTheme = await shelfRepo.getSetting('app_theme');
    if (savedTheme != null && savedTheme.isNotEmpty) themeId = themeById(savedTheme).id;
    final String? savedMode = await shelfRepo.getSetting('app_theme_mode');
    if (savedMode == 'system' || savedMode == 'light' || savedMode == 'dark') {
      themeModeId = savedMode!;
    }
    // 哔咔这类要登录的源：token 存本地，重启后直接复用。
    final String? picaToken = await shelfRepo.getSetting('pica_token');
    if (picaToken != null && picaToken.isNotEmpty) {
      engine.pica.token = picaToken;
      unawaited(_refreshPicaUser());
    }
    final String? picaUuid = await shelfRepo.getSetting('pica_uuid');
    if (picaUuid != null && picaUuid.isNotEmpty) engine.pica.uuid = picaUuid;
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

  // ------------------------------------------------------------ 书源订阅

  static const String _subscriptionKey = 'source_subscriptions';

  List<SourceSubscription> subscriptions = <SourceSubscription>[];

  Future<void> reloadSubscriptions() async {
    final String? raw = await shelfRepo.getSetting(_subscriptionKey);
    if (raw == null || raw.trim().isEmpty) {
      subscriptions = <SourceSubscription>[];
      notifyListeners();
      return;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      subscriptions = decoded is List
          ? decoded
              .whereType<Map<String, dynamic>>()
              .map(SourceSubscription.fromJson)
              .where((SourceSubscription s) => s.url.isNotEmpty)
              .toList()
          : <SourceSubscription>[];
    } on Object {
      subscriptions = <SourceSubscription>[];
    }
    notifyListeners();
  }

  Future<void> _persistSubscriptions() async {
    await shelfRepo.setSetting(
      _subscriptionKey,
      jsonEncode(subscriptions
          .map((SourceSubscription s) => s.toJson())
          .toList(growable: false)),
    );
    notifyListeners();
  }

  /// 拉一个订阅地址，把里面的书源写进库。返回一句给人看的结论文本。
  Future<String> syncSubscription(SourceSubscription sub) async {
    final String url = sub.url.trim();
    if (url.isEmpty) return '订阅地址是空的';
    String body;
    try {
      final res = await engine.http.request(
        url,
        headers: <String, String>{
          'User-Agent': TextUtil.userAgent,
          'Accept': 'application/json, text/plain, */*',
        },
      );
      if (!res.isOk) return '拉取失败：HTTP ${res.statusCode}';
      body = res.body;
    } on RuleException catch (e) {
      return '拉取失败：${e.message}';
    }

    final List<BookSource> parsed = SourceRepo.parseSources(body);
    if (parsed.isEmpty) return '这个地址里没解析出书源（可能不是书源 JSON）';

    // 已有书源保留用户的启用/停用选择
    final Map<String, bool> keepEnabled = <String, bool>{
      for (final BookSource s in sources) s.url: s.enabled,
    };
    final List<BookSource> toSave = <BookSource>[
      for (final BookSource s in parsed)
        keepEnabled.containsKey(s.url) && keepEnabled[s.url] != s.enabled
            ? s.copyWithEnabled(keepEnabled[s.url]!)
            : s,
    ];
    final int n = await sourceRepo.saveAll(toSave);

    final int idx = subscriptions.indexWhere((SourceSubscription s) => s.url == url);
    final SourceSubscription updated = SourceSubscription(
      url: url,
      name: sub.name.trim().isNotEmpty
          ? sub.name.trim()
          : (parsed.first.name.isNotEmpty ? parsed.first.name : sub.displayName),
      count: n,
      lastSync: DateTime.now().millisecondsSinceEpoch,
    );
    if (idx >= 0) {
      subscriptions[idx] = updated;
    } else {
      subscriptions.add(updated);
    }
    await _persistSubscriptions();
    await reloadSources();
    return '「${updated.displayName}」已更新 $n 个书源';
  }

  Future<String> addSubscription(String url) async {
    final String clean = url.trim();
    if (clean.isEmpty) return '订阅地址是空的';
    if (!clean.startsWith('http')) return '订阅地址要以 http 开头';
    if (subscriptions.any((SourceSubscription s) => s.url == clean)) {
      return '这个地址已经订阅过了';
    }
    subscriptions.add(SourceSubscription(url: clean));
    await _persistSubscriptions();
    return syncSubscription(SourceSubscription(url: clean));
  }

  Future<void> removeSubscription(String url) async {
    subscriptions.removeWhere((SourceSubscription s) => s.url == url);
    await _persistSubscriptions();
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

  // ------------------------------------------------------------- 哔咔（原生源）

  /// 登录哔咔：成功返回昵称（可能为空），失败抛 RuleException。
  Future<String> picaLogin(String email, String password) async {
    final String token = await engine.pica.signIn(email, password);
    await shelfRepo.setSetting('pica_token', token);
    if (engine.pica.uuid.isEmpty) {
      await shelfRepo.setSetting('pica_uuid', engine.pica.uuid);
    }
    picaUserName = '';
    await _refreshPicaUser();
    notifyListeners();
    return picaUserName;
  }

  Future<void> picaLogout() async {
    engine.pica.token = null;
    picaUserName = '';
    await shelfRepo.setSetting('pica_token', '');
    notifyListeners();
  }

  Future<void> _refreshPicaUser() async {
    if (engine.pica.token == null || engine.pica.token!.isEmpty) return;
    try {
      picaUserName = await engine.pica.me();
      notifyListeners();
    } catch (_) {
      // token 过期之类的问题不打扰用户，等真正搜索时再报。
    }
  }

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

  // ------------------------------------------------------------- 换源（多源）

  /// 在其它源里找同一本书。命中一个就通过 [onCandidate] 抛一个，UI 可以边搜边显示。
  Future<List<SourceCandidate>> findSourcesFor(
    ShelfBook book, {
    void Function(SourceCandidate candidate)? onCandidate,
  }) async {
    final String want = normBookName(book.name);
    final List<SourceCandidate> out = <SourceCandidate>[];
    for (final BookSource source in searchableSources) {
      if (source.url == book.sourceUrl) continue;
      try {
        final List<SearchBook> hits = await engine
            .search(source, book.name)
            .timeout(const Duration(seconds: 25));
        SearchBook? best;
        for (final SearchBook h in hits) {
          final String got = normBookName(h.name);
          if (got == want ||
              (got.length >= 2 && (got.contains(want) || want.contains(got)))) {
            best = h;
            break;
          }
        }
        if (best == null) continue;
        final SourceCandidate c = SourceCandidate(source: source, book: best);
        out.add(c);
        onCandidate?.call(c);
      } catch (_) {
        // 单个源失败不影响整张候选表
      }
    }
    return out;
  }

  /// 把书架上这本书切到 [cand] 这个源，返回新章节与迁移后的进度。
  ///
  /// 章节缓存跟着新的 bookUrl 走；旧条目连同旧缓存一起删掉，避免留下僵尸书。
  Future<SwitchResult> switchSource(
    ShelfBook book,
    SourceCandidate cand, {
    String? chapterTitle,
  }) async {
    final BookInfo info = await engine.bookInfo(cand.source, cand.book.bookUrl);
    final List<BookChapter> chapters = await engine.chapters(cand.source, info);
    if (chapters.isEmpty) {
      throw RuleException('这个源没解析到目录，换不过去');
    }
    int index = 0;
    final String title = (chapterTitle ?? '').trim();
    if (title.isNotEmpty) index = matchChapterIndex(chapters, title);

    final int now = DateTime.now().millisecondsSinceEpoch;
    final String nextUrl =
        info.bookUrl.isEmpty ? cand.book.bookUrl : info.bookUrl;
    final ShelfBook next = ShelfBook(
      bookUrl: nextUrl,
      name: info.name.isEmpty ? book.name : info.name,
      author: info.author.isEmpty ? book.author : info.author,
      cover: info.cover,
      intro: info.intro.isEmpty ? book.intro : info.intro,
      kind: info.kind.isEmpty ? book.kind : info.kind,
      sourceUrl: cand.source.url,
      sourceName: cand.source.name,
      type: cand.source.type,
      tocUrl: info.tocUrl,
      totalChapters: chapters.length,
      latestChapter: chapters.isEmpty ? '' : chapters.last.title,
      lastReadIndex: index,
      lastReadOffset: 0,
      lastReadTime: now,
      createdTime: book.createdTime == 0 ? now : book.createdTime,
    );

    await shelfRepo.saveChapters(next.bookUrl, chapters);
    if (next.bookUrl != book.bookUrl) {
      await shelfRepo.remove(book.bookUrl);
    }
    await shelfRepo.upsert(next);
    await reloadShelf();
    notifyListeners();
    return SwitchResult(book: next, chapters: chapters, index: index);
  }

  /// 把书名压成可比较的形状：去空白、去标点、统一大小写。
  static final RegExp _nameNoise = RegExp(
    r'''[\s\u3000《》〈〉（）()\[\]【】·、，,。.!！?？:：;；"“”'`~～\-—_]+''',
  );

  static String normBookName(String raw) =>
      raw.replaceAll(_nameNoise, '').toLowerCase();

  /// 在新源目录里找与 [title] 最像的一章（先精确、再包含），找不到就第 0 章。
  static int matchChapterIndex(List<BookChapter> chapters, String title) {
    final String want = normBookName(title);
    for (int i = 0; i < chapters.length; i++) {
      if (normBookName(chapters[i].title) == want) return i;
    }
    if (want.isNotEmpty) {
      for (int i = 0; i < chapters.length; i++) {
        final String got = normBookName(chapters[i].title);
        if (got.isEmpty) continue;
        if (got.contains(want) || want.contains(got)) return i;
      }
    }
    return 0;
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
    // 内存里的书架对象同步改：否则回到书架再点「继续阅读」用的还是旧章节。
    final int i =
        shelf.indexWhere((ShelfBook b) => b.bookUrl == book.bookUrl);
    if (i < 0) return;
    final ShelfBook b = shelf[i];
    b.lastReadIndex = index;
    b.lastReadOffset = offset;
    b.lastReadTime = DateTime.now().millisecondsSinceEpoch;
    book.lastReadIndex = index;
    book.lastReadOffset = offset;
    book.lastReadTime = b.lastReadTime;
    shelf.sort(
        (ShelfBook x, ShelfBook y) => y.lastReadTime.compareTo(x.lastReadTime));
    // 滚动模式每停一次都会调这里，节流一下避免书架反复重建。
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastProgressNotify > 1200) {
      _lastProgressNotify = now;
      notifyListeners();
    }
  }

  int _lastProgressNotify = 0;

  // ------------------------------------------------------------------ prefs

  Future<void> updatePrefs(ReadPrefs next) async {
    prefs = next;
    notifyListeners();
    await shelfRepo.setSetting('read_prefs', _encodePrefs(next));
  }

  /// 切换整体主题（颜色 + 组件样式），立即生效并持久化。
  /// 切换主题模式（跟随系统 / 浅色 / 深色），立即生效并持久化。
  Future<void> setThemeMode(String id) async {
    if (id == themeModeId) return;
    themeModeId = id;
    notifyListeners();
    await shelfRepo.setSetting('app_theme_mode', id);
  }

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
