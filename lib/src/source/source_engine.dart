import 'dart:convert';

import '../core/rule_exception.dart';
import '../core/text_util.dart';
import '../model/book_info.dart';
import '../model/book_source.dart';
import '../model/search_book.dart';
import '../net/http_service.dart';
import '../net/rate_limiter.dart';
import '../rule/js_engine.dart';
import '../rule/rule_context.dart';
import '../rule/rule_parser.dart';

/// 把「书源规则」跑成真正的数据。
///
/// 这里是整个 App 的核心：所有内容都来自用户导入的书源 JSON，
/// 代码里不写死任何站点。
class SourceEngine {
  SourceEngine({HttpService? http}) : http = http ?? HttpService() {
    js = JsEngine(
      fetch: (JsRequest r) async {
        final HttpResult res = await this.http.request(
          r.url,
          method: r.method,
          body: r.body.isEmpty ? null : r.body,
          headers: r.headers,
        );
        return res.body;
      },
    );
    parser = RuleParser(js: js);
  }

  final HttpService http;
  late final JsEngine js;
  late final RuleParser parser;

  final Map<String, Map<String, String>> _headerCache =
      <String, Map<String, String>>{};

  /// 每个书源当前生效的镜像地址（key 用书源原始 url）。空 = 用原地址。
  ///
  /// 为什么要记：同一个站常有好几个域名（bzmh.org / baozimh.org …），
  /// 某一个被墙了就换下一个；换成功之后整轮操作都继续用它，
  /// 免得每页都先撞一次墙。
  final Map<String, String> _activeMirror = <String, String>{};

  /// 当前生效的镜像（没有就是空串）。
  String activeMirrorOf(BookSource source) => _activeMirror[source.url] ?? '';

  void resetMirror(BookSource source) => _activeMirror.remove(source.url);

  /// 把 url 里的原站主机名换成镜像主机名。
  static String swapHost(String url, String fromBase, String toBase) {
    final Uri? from = Uri.tryParse(fromBase.trim());
    final Uri? to = Uri.tryParse(toBase.trim());
    if (from == null || to == null) return url;
    if (from.host.isEmpty || to.host.isEmpty) return url;
    if (from.host == to.host) return url;
    return url.replaceAll(from.host, to.host);
  }

  /// 网络层面的失败才值得换镜像；规则写错了换多少次都一样。
  static bool _isNetworkFailure(RuleException e) =>
      e.message.contains('网络请求失败') ||
      e.message.contains('超时') ||
      e.message.contains('人机验证') ||
      e.message.contains('连接');

  /// 带镜像回退的请求：先试当前生效地址，网络失败就按 `mirrors` 顺序换下一个。
  Future<HttpResult> _fetch(
    BookSource source,
    String url, {
    String method = 'GET',
    Map<String, String>? headers,
    String? body,
    Map<String, dynamic>? query,
    String? charset,
  }) async {
    final List<String> order = <String>[
      if (_activeMirror[source.url] != null) _activeMirror[source.url]!,
      source.url,
      ...source.mirrors,
    ];
    final List<String> tried = <String>[];
    RuleException? last;
    for (final String base in order) {
      final String target = swapHost(url, source.url, base);
      if (tried.contains(target)) continue;
      tried.add(target);
      try {
        final HttpResult res = await http.request(
          target,
          method: method,
          headers: headers,
          body: body,
          query: query,
          charset: charset,
        );
        if (base.trim().isNotEmpty && base.trim() != source.url) {
          _activeMirror[source.url] = base.trim();
        }
        return res;
      } on RuleException catch (e) {
        last = e;
        if (!_isNetworkFailure(e)) rethrow;
      }
    }
    throw last ??
        RuleException('请求失败', detail: '书源 ${source.name} 没有可用地址');
  }

  void dispose() {
    js.dispose();
    http.dispose();
  }

  /// 切换书源时清理 JS 上下文（加密参数等）。
  void resetJs() => js.reset();

  /// 按书源的 `concurrentRate`（Legado 写法 `"间隔毫秒/并发数"`）给对应域名限速。
  void _applyRateLimit(BookSource source) {
    final ({Duration interval, int concurrency})? rate =
        RateLimiter.parseRate(source.concurrentRate);
    if (rate == null) return;
    http.limiter.configure(
      TextUtil.hostOf(source.url),
      interval: rate.interval,
      concurrency: rate.concurrency,
    );
  }

  // --------------------------------------------------------------- headers

  Future<Map<String, String>> headersOf(BookSource source) async {
    _applyRateLimit(source);
    final Map<String, String>? cached = _headerCache[source.url];
    if (cached != null) return cached;

    final Map<String, String> headers = <String, String>{};
    final String host = TextUtil.hostOf(source.url);
    if (source.url.trim().isNotEmpty) {
      headers['Referer'] = source.url.trim();
    } else if (host.isNotEmpty) {
      headers['Referer'] = host;
    }

    for (final MapEntry<String, String> e in source.header.entries) {
      final String key = e.key.trim();
      if (key.isEmpty) continue;
      String value = e.value.trim();
      if (value.isEmpty) {
        headers.remove(key);
        continue;
      }
      if (value.startsWith('{{') || value.startsWith('@js:')) {
        try {
          value = await js.runString(
            value.startsWith('@js:')
                ? value.substring(4)
                : value.substring(2, value.length - 2),
            baseUrl: source.url,
            sourceUrl: source.url,
            sourceName: source.name,
          );
        } catch (_) {
          value = '';
        }
      }
      if (value.isEmpty) {
        headers.remove(key);
      } else {
        headers[key] = value;
      }
    }
    _headerCache[source.url] = headers;
    return headers;
  }

  // ---------------------------------------------------------------- search

  Future<List<SearchBook>> search(
    BookSource source,
    String key, {
    int page = 1,
  }) async {
    if (!source.canSearch) {
      throw RuleException('书源「${source.name}」未配置搜索地址');
    }
    resetJs();
    final Map<String, String> headers = await headersOf(source);
    final _RequestSpec spec = await _buildSearchRequest(source, key, page);

    final HttpResult res = await _fetch(
      source,
      spec.url,
      method: spec.method,
      body: spec.body,
      charset: spec.charset,
      headers: <String, String>{...headers, ...spec.headers},
    );
    if (!res.isOk) {
      throw RuleException('搜索失败：HTTP ${res.statusCode}');
    }

    final RuleContext ctx = RuleContext.page(
      res.body,
      baseUrl: res.url,
      headers: headers,
      sourceUrl: source.url,
      sourceName: source.name,
    );
    await _runInit(source.ruleBookInfo.init, ctx);

    final SearchRule rule = source.ruleSearch;
    final List<dynamic> items = await parser.evalList(rule.bookList, ctx);

    final List<SearchBook> out = <SearchBook>[];
    final Set<String> seen = <String>{};

    for (final dynamic item in items) {
      final RuleContext c = ctx.child(item);
      final String name = await parser.evalString(rule.name, c);
      final String bookUrl = await parser.evalUrl(rule.bookUrl, c);

      if (name.isEmpty || bookUrl.isEmpty) continue;
      if (!seen.add(bookUrl)) continue;

      if (rule.checkKeyWord.trim().isNotEmpty) {
        final String check = await parser.evalString(rule.checkKeyWord, c);
        if (check.contains('false')) continue;
      }

      out.add(
        SearchBook(
          name: _clean(name),
          author: _clean(await parser.evalString(rule.author, c)),
          bookUrl: bookUrl,
          cover: await parser.evalUrl(rule.coverUrl, c),
          intro: _clean(await parser.evalString(rule.intro, c)),
          kind: _clean(await parser.evalString(rule.kind, c)),
          lastChapter: _clean(await parser.evalString(rule.lastChapter, c)),
          updateTime: _clean(await parser.evalString(rule.updateTime, c)),
          wordCount: _clean(await parser.evalString(rule.wordCount, c)),
          sourceUrl: source.url,
          sourceName: source.name,
          type: source.type,
        ),
      );
    }
    return _filterByKeyWord(out, key, rule);
  }

  /// 有些站点根本不是「按关键词搜」：查不到时会把「全部/热门/排行榜」列表返回
  /// （漢典古籍、哔哩轻小说、カクヨム、看漫画都这样），照搬就是一屏不相干的书。
  /// 这里做一层客户端相关性过滤：
  /// - 结果 ≥4 条且一条都不含关键词 → 判定「该站没有这本书」，返回空；
  /// - 有条目命中关键词 → 只保留命中的；
  /// - 结果本来就少（<4）→ 原样返回，避免误伤按作者/拼音搜索的源。
  /// - 接口型源（bookList 用 `@Json:`）跳过：那是站点自己按关键词匹配的，
  ///   标题还可能被翻译（MangaDex 搜「チェンソー」返回 "Chainsaw Man"），
  ///   再按字面过滤会把正确结果全杀掉。
  List<SearchBook> _filterByKeyWord(
    List<SearchBook> list,
    String key,
    SearchRule rule,
  ) {
    final String k = key.trim();
    if (k.isEmpty || list.length < 4) return list;
    if (rule.bookList.contains('@Json:')) return list;
    final String norm = _normalize(k);
    final List<SearchBook> hit = list
        .where((SearchBook b) =>
            b.name.contains(k) || _normalize(b.name).contains(norm))
        .toList(growable: false);
    if (hit.isEmpty) return const <SearchBook>[];
    if (hit.length == list.length) return list;
    return hit;
  }

  /// 去掉空白与常见标点，让「钢铁是怎样炼成的」也能命中「钢铁是怎样炼成的(完)」这类标题。
  static String _normalize(String s) => s
      .replaceAll(RegExp(r'[\s\u3000]'), '')
      .replaceAll(RegExp(r'[《》「」『』（）()\[\]【】·:：,，.。!！?？\-—_/\\]'), '')
      .toLowerCase();

  // -------------------------------------------------------------- bookInfo

  /// [fallbackName]/[fallbackAuthor]/[fallbackIntro]/[fallbackCover] 来自搜索结果：
  /// Legado 的语义是「详情页规则留空就沿用搜索结果的字段」，很多源就是靠这个显示书名/封面。
  Future<BookInfo> bookInfo(
    BookSource source,
    String bookUrl, {
    String? fallbackName,
    String? fallbackAuthor,
    String? fallbackIntro,
    String? fallbackCover,
  }) async {
    resetJs();
    final Map<String, String> headers = await headersOf(source);
    final HttpResult res = await _fetch(source, bookUrl, headers: headers);
    if (!res.isOk) {
      throw RuleException('打开书籍失败：HTTP ${res.statusCode}');
    }
    final RuleContext ctx = RuleContext.page(
      res.body,
      baseUrl: res.url,
      headers: headers,
      sourceUrl: source.url,
      sourceName: source.name,
    );
    final BookInfoRule rule = source.ruleBookInfo;
    await _runInit(rule.init, ctx);
    final List<String> groups = _initGroups(rule.init, res.body);
    String g(String r) => _applyInitGroups(r, groups);

    String tocUrl = await parser.evalUrl(g(rule.tocUrl), ctx);
    if (tocUrl.isEmpty) tocUrl = res.url;

    String pick(String parsed, String? fallback) =>
        parsed.isNotEmpty ? parsed : (fallback ?? '').trim();

    return BookInfo(
      name: pick(_clean(await parser.evalString(g(rule.name), ctx)), fallbackName),
      author: pick(_clean(await parser.evalString(g(rule.author), ctx)),
          fallbackAuthor),
      intro:
          pick(_clean(await parser.evalString(g(rule.intro), ctx)), fallbackIntro),
      kind: _clean(await parser.evalString(g(rule.kind), ctx)),
      cover: await parser.evalUrl(g(rule.coverUrl), ctx).then(
          (String v) => v.isNotEmpty ? v : (fallbackCover ?? '')),
      lastChapter: _clean(await parser.evalString(g(rule.lastChapter), ctx)),
      updateTime: _clean(await parser.evalString(g(rule.updateTime), ctx)),
      wordCount: _clean(await parser.evalString(g(rule.wordCount), ctx)),
      bookUrl: res.url,
      tocUrl: tocUrl,
      type: source.type,
    );
  }

  // -------------------------------------------------------------- chapters

  Future<List<BookChapter>> chapters(
    BookSource source,
    BookInfo info, {
    int maxPages = 40,
  }) async {
    final Map<String, String> headers = await headersOf(source);
    final TocRule rule = source.ruleToc;

    final List<BookChapter> out = <BookChapter>[];
    final Set<String> visited = <String>{};
    final Set<String> seenUrl = <String>{};
    String next = info.tocUrl.isEmpty ? info.bookUrl : info.tocUrl;

    int page = 0;
    while (next.isNotEmpty && page < maxPages) {
      if (!visited.add(next)) break;
      page++;

      final HttpResult res = await _fetch(source, next, headers: headers);
      if (!res.isOk) break;
      final RuleContext ctx = RuleContext.page(
        res.body,
        baseUrl: res.url,
        headers: headers,
        sourceUrl: source.url,
        sourceName: source.name,
      );

      final List<dynamic> items = await parser.evalList(rule.chapterList, ctx);
      final int before = out.length;
      for (final dynamic item in items) {
        final RuleContext c = ctx.child(item);
        final String title = _clean(await parser.evalString(rule.chapterName, c));
        final String url = await parser.evalUrl(rule.chapterUrl, c);
        if (title.isEmpty || url.isEmpty) continue;
        if (!seenUrl.add(url)) continue;
        final String vip = await parser.evalString(rule.isVip, c);
        out.add(
          BookChapter(
            title: title,
            url: url,
            index: out.length,
            isVip: vip.trim().toLowerCase() == 'true',
          ),
        );
      }

      // 有的站点最后一页仍挂着「下一页」链接，取不到新章节就停
      if (page > 1 && out.length == before) break;

      final String nextUrl = await parser.evalUrl(rule.nextTocUrl, ctx);
      next = nextUrl;
    }

    if (out.isEmpty) {
      throw RuleException('目录为空，可能是书源规则失效或站点改版');
    }

    // 反向目录（不少站点倒序）由 UI 决定是否翻转，这里保持原顺序。
    return out;
  }

  // --------------------------------------------------------------- content

  Future<BookContent> content(
    BookSource source,
    BookChapter chapter, {
    int maxPages = 8,
  }) async {
    final Map<String, String> headers = await headersOf(source);
    final ContentRule rule = source.ruleContent;
    if (rule.content.trim().isEmpty) {
      throw RuleException('书源「${source.name}」未配置正文规则');
    }

    String url = chapter.url;
    final Set<String> visited = <String>{};
    final List<String> images = <String>[];
    final List<String> texts = <String>[];
    int page = 0;

    while (url.isNotEmpty && page < maxPages) {
      if (!visited.add(url)) break;
      page++;

      final HttpResult res = await _fetch(source, url, headers: headers);
      if (!res.isOk) {
        throw RuleException('加载章节失败：HTTP ${res.statusCode}');
      }
      final RuleContext ctx = RuleContext.page(
        res.body,
        baseUrl: res.url,
        headers: headers,
        sourceUrl: source.url,
        sourceName: source.name,
      );

      if (source.isComic) {
        final List<String> imgs = await parser.evalImageList(rule.content, ctx);
        for (final String img in imgs) {
          if (!images.contains(img)) images.add(img);
        }
      } else {
        String html = await parser.evalHtml(rule.content, ctx);
        html = _postProcess(html, rule);
        if (html.isNotEmpty) texts.add(html);
      }

      final String nextUrl = await parser.evalUrl(rule.nextContentUrl, ctx);
      url = nextUrl;
    }

    if (source.isComic) {
      if (images.isEmpty) {
        throw RuleException('未解析到漫画图片，书源规则可能失效');
      }
      return BookContent(images: images, title: chapter.title);
    }

    final String text = texts.join('\n');
    if (text.isEmpty) {
      throw RuleException('正文为空，书源规则可能失效');
    }
    return BookContent(text: text, title: chapter.title);
  }

  // -------------------------------------------------------------- internals

  String _postProcess(String html, ContentRule rule) {
    String out = html;

    final String src = rule.sourceRegex.trim();
    if (src.isNotEmpty) {
      final List<String> parts = src.split('##');
      if (parts.isNotEmpty && parts[0].isNotEmpty) {
        try {
          final RegExpMatch? m = RegExp(parts[0], dotAll: true).firstMatch(out);
          if (m != null && m.groupCount >= 1) {
            out = m.group(1) ?? out;
          } else if (m != null) {
            out = m.group(0) ?? out;
          }
        } catch (_) {}
      }
    }

    final String rep = rule.replaceRegex.trim();
    if (rep.isNotEmpty) {
      final List<String> parts = rep.split('##');
      for (int i = 0; i + 1 < parts.length; i += 2) {
        final String pattern = parts[i];
        final String replacement = parts[i + 1];
        if (pattern.isEmpty) continue;
        try {
          out = out.replaceAll(RegExp(pattern, multiLine: true, dotAll: true),
              replacement);
        } catch (_) {}
      }
    }
    return out.trim();
  }

  Future<void> _runInit(String rule, RuleContext ctx) async {
    final String r = rule.trim();
    if (r.isEmpty) return;
    try {
      await parser.evalList(r, ctx);
    } catch (_) {
      // init 失败不阻断主流程
    }
  }

  /// 执行 `ruleBookInfo.init` 这种「先用正则抓分组」的规则。
  ///
  /// 返回下标 0 为整段匹配、1..n 为捕获组；之后详情页各字段里的 `$1`/`$4`
  /// 就从这里取值（Legado 的做法）。
  List<String> _initGroups(String rule, String html) {
    String pattern = rule.trim();
    if (pattern.isEmpty) return const <String>[];
    if (pattern.startsWith('@js:') ||
        pattern.toLowerCase().startsWith('<js>') ||
        pattern.startsWith('{{')) {
      return const <String>[];
    }
    if (pattern.startsWith(':')) pattern = pattern.substring(1);
    try {
      final RegExpMatch? m = RegExp(pattern, dotAll: true, multiLine: true)
          .firstMatch(html);
      if (m == null) return const <String>[];
      return <String>[for (int i = 0; i <= m.groupCount; i++) m.group(i) ?? ''];
    } catch (_) {
      return const <String>[];
    }
  }

  /// 把字段规则里的 `$1`/`$4` 换成 init 抓到的分组值。
  ///
  /// 带 `##正则##替换`、`@js:`、`@css:` 等标记的规则里 `$1` 是它自己的捕获组，
  /// 不能替换，因此直接放过。
  String _applyInitGroups(String rule, List<String> groups) {
    if (groups.isEmpty) return rule;
    if (!rule.contains(r'$')) return rule;
    if (rule.contains('##') ||
        rule.startsWith('@js:') ||
        rule.toLowerCase().startsWith('<js>') ||
        rule.startsWith('@css:') ||
        rule.startsWith('//') ||
        rule.startsWith('@xpath:') ||
        rule.contains('@')) {
      return rule;
    }
    return rule.replaceAllMapped(RegExp(r'\$(\d+)'), (Match m) {
      final int i = int.parse(m.group(1)!);
      return i < groups.length ? groups[i] : '';
    });
  }

  String _clean(String input) => TextUtil.squeeze(input);

  Future<_RequestSpec> _buildSearchRequest(
    BookSource source,
    String key,
    int page,
  ) async {
    String raw = source.searchUrl.trim();

    // 允许 searchUrl 本身就是一段 JS
    if (raw.startsWith('{{') || raw.startsWith('@js:')) {
      final String produced = await js.runString(
        raw.startsWith('@js:')
            ? raw.substring(4)
            : raw.substring(2, raw.length - 2),
        result: key,
        baseUrl: source.url,
        sourceUrl: source.url,
        sourceName: source.name,
      );
      raw = produced.trim();
    }

    Map<String, dynamic> options = <String, dynamic>{};
    final int optIdx = raw.lastIndexOf(',{');
    if (optIdx > 0 && raw.trimRight().endsWith('}')) {
      final String jsonPart = raw.substring(optIdx + 1);
      try {
        final Object? parsed = jsonDecode(jsonPart);
        if (parsed is Map<String, dynamic>) {
          options = parsed;
          raw = raw.substring(0, optIdx);
        }
      } catch (_) {
        // 不是选项，按普通 URL 处理
      }
    }

    final String method =
        (options['method']?.toString() ?? 'GET').toUpperCase();
    final String bodyTpl = options['body']?.toString() ?? '';
    final Map<String, String> extraHeaders = <String, String>{};
    final Object? h = options['headers'];
    if (h is Map) {
      h.forEach((Object? k, Object? v) {
        if (k != null && v != null) {
          extraHeaders[k.toString()] = v.toString();
        }
      });
    }

    final String url = TextUtil.resolveUrl(
      source.url,
      _encodeLoose(_substitute(raw, key, page, encode: true)),
    );
    final String body = _substitute(bodyTpl, key, page, encode: false);

    return _RequestSpec(
      url: url,
      method: method,
      body: body,
      headers: extraHeaders,
      charset: options['charset']?.toString(),
    );
  }

  String _substitute(String template, String key, int page,
      {required bool encode}) {
    String k = key;
    if (encode) k = _encodeLoose(key);
    return template
        .replaceAll('{{key}}', k)
        .replaceAll('{{page}}', page.toString())
        .replaceAll('searchKey', encode ? k : key)
        .replaceAll('searchPage', page.toString());
  }

  /// 只对非 ASCII 与空白做百分号编码，保留 URL 结构字符。
  String _encodeLoose(String input) {
    final StringBuffer sb = StringBuffer();
    for (final int rune in input.runes) {
      if (rune > 0x20 && rune < 0x7f) {
        sb.writeCharCode(rune);
      } else {
        for (final int b in utf8.encode(String.fromCharCode(rune))) {
          sb.write('%${b.toRadixString(16).toUpperCase().padLeft(2, '0')}');
        }
      }
    }
    return sb.toString();
  }
}

class _RequestSpec {
  const _RequestSpec({
    required this.url,
    required this.method,
    required this.body,
    required this.headers,
    this.charset,
  });

  final String url;
  final String method;
  final String body;
  final Map<String, String> headers;
  final String? charset;
}
