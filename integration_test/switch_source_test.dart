// 换源回归：两个「假站点」（mock 传输层）+ 真 SQLite + 真 AppState。
// 验证：搜到同名书 → 列出候选 → 切换后书架条目/目录缓存/阅读进度都迁过去。
// 跑法：flutter test integration_test/switch_source_test.dart -d windows
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noval/src/app_state.dart';
import 'package:noval/src/db/database.dart';
import 'package:noval/src/model/book_info.dart';
import 'package:noval/src/model/book_source.dart';
import 'package:noval/src/model/shelf_book.dart';

import '../test/mock_http_adapter.dart';

const String kDbPath = 'tool/switch_source_test.db';

/// A 站：只有 3 章；B 站：同名书，6 章，第 3 章标题与 A 站第 3 章一致。
const String kBookName = '妹妹人生';

String _searchHtml(String site) => '''
<html><body>
<div class="item"><a href="https://$site.test/book/1">$kBookName</a>
<span class="author">作者$site</span></div>
</body></html>''';

String _bookHtml(String site) => '''
<html><body>
<h1>$kBookName</h1><div class="intro">$site 站的简介</div>
<a class="toc" href="https://$site.test/toc/1">目录</a>
</body></html>''';

String _tocHtml(String site, int count) {
  final StringBuffer sb = StringBuffer('<html><body><ul class="chapters">');
  for (int i = 1; i <= count; i++) {
    final String title = i == 3 ? '第三章 雨' : '第$i章 $site';
    sb.writeln('<li><a href="https://$site.test/ch/$i">$title</a></li>');
  }
  sb.write('</ul></body></html>');
  return sb.toString();
}

String _contentHtml(String site) =>
    '<html><body><div id="content"><p>$site 的正文，够长够长。</p></div></body></html>';

Map<String, Object?> _sourceJson(String site, String name) => <String, Object?>{
      'bookSourceName': name,
      'bookSourceUrl': 'https://$site.test',
      'bookSourceGroup': '测试',
      'enabled': true,
      'searchUrl': '/search?q={{key}}',
      'ruleSearch': <String, Object?>{
        'bookList': '@css:div.item',
        'name': '@css:a@text',
        'author': '@css:span.author@text',
        'bookUrl': '@css:a@href',
        'intro': '',
        'coverUrl': '',
      },
      'ruleBookInfo': <String, Object?>{
        'name': '@css:h1@text',
        'intro': '@css:div.intro@text',
        'tocUrl': '@css:a.toc@href',
      },
      'ruleToc': <String, Object?>{
        'chapterList': '@css:ul.chapters li',
        'chapterName': '@css:a@text',
        'chapterUrl': '@css:a@href',
      },
      'ruleContent': <String, Object?>{
        'content': '@css:#content@html',
      },
    };

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final File f = File(kDbPath);
    if (f.existsSync()) f.deleteSync();
    await AppDatabase.instance.init(path: kDbPath);
  });

  tearDownAll(() async {
    await AppDatabase.instance.close();
    final File f = File(kDbPath);
    if (f.existsSync()) f.deleteSync();
  });

  test('换源：候选 → 切换 → 进度与缓存迁移', () async {
    final AppState st = AppState();
    await st.bootstrap();
    expect(st.ready, isTrue);

    // 用假传输层接管网络：按 host 分派两个站
    st.engine.http.useAdapter(MockHttpAdapter((options) {
      final String uri = options.uri.toString();
      final bool isA = uri.contains('a.test');
      final String site = isA ? 'a' : 'b';
      if (uri.contains('/search')) return mockHtml(_searchHtml(site));
      if (uri.contains('/book/1')) return mockHtml(_bookHtml(site));
      if (uri.contains('/toc/1')) {
        return mockHtml(_tocHtml(site, isA ? 3 : 6));
      }
      if (uri.contains('/ch/')) return mockHtml(_contentHtml(site));
      return MockReply(404, 'no route $uri');
    }));

    final int n = await st.importText(
      '[${_jsonSource(_sourceJson('a', 'A源'))},${_jsonSource(_sourceJson('b', 'B源'))}]',
    );
    expect(n, 2);
    st.sources = st.sources.where((BookSource s) => s.name == 'A源' || s.name == 'B源').toList();
    expect(st.sources.length, 2);

    // 从 A 源入架，读到第 3 章
    final BookSource a = st.sources.firstWhere((BookSource s) => s.name == 'A源');
    final BookInfo info = await st.engine.bookInfo(a, 'https://a.test/book/1');
    final ShelfBook book = ShelfBook.fromInfo(
      info,
      sourceUrl: a.url,
      sourceName: a.name,
      type: SourceType.text,
    );
    book.lastReadIndex = 2;
    await st.addToShelf(book);
    expect(await st.inShelf(book.bookUrl), isTrue);

    // 换源候选：应只从 B 源找到同名书
    final List<SourceCandidate> cands = await st.findSourcesFor(book);
    expect(cands.length, 1, reason: 'A 源自己要跳过，B 源有同名书');
    expect(cands.first.source.name, 'B源');
    expect(AppState.normBookName(cands.first.book.name), AppState.normBookName(kBookName));

    // 切过去：进度按章节名迁移到 B 源的第 3 章（下标 2）
    final SwitchResult r =
        await st.switchSource(book, cands.first, chapterTitle: '第三章 雨');
    expect(r.chapters.length, 6);
    expect(r.index, 2);
    expect(r.book.sourceName, 'B源');
    expect(r.book.bookUrl, 'https://b.test/book/1');
    expect(r.book.totalChapters, 6);
    expect(r.book.lastReadIndex, 2);

    // 书架：旧条目清掉、新条目在，目录缓存跟着新 bookUrl
    expect(await st.inShelf(book.bookUrl), isFalse, reason: '旧源条目应被删除');
    expect(await st.inShelf(r.book.bookUrl), isTrue);
    expect(st.shelf.length, 1);
    final List<BookChapter> cached = await st.loadChapters(r.book);
    expect(cached.length, 6);

    // 新源正文能读
    final BookContent content = await st.loadContent(r.book, cached[2]);
    expect(content.text.contains('b 的正文'), isTrue);
  });
}

String _jsonSource(Map<String, Object?> m) => jsonEncode(m);
