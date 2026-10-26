// 端到端验证「书源规则里写 JavaScript」这条链路（需要 quickjs 原生库，
// 所以只能用 integration_test 在桌面上跑）：
//
//   flutter test integration_test/js_source_test.dart -d windows
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noval/src/db/source_repo.dart';
import 'package:noval/src/model/book_info.dart';
import 'package:noval/src/model/book_source.dart';
import 'package:noval/src/model/search_book.dart';
import 'package:noval/src/source/source_engine.dart';
import 'package:noval/src/ui/reader/read_theme.dart';

import '../tool/mock_site_server.dart';

String _sourceJson(String base) => '''
[
  {
    "bookSourceUrl": "$base",
    "bookSourceName": "本地假站-JS 源",
    "bookSourceType": 0,
    "enabled": true,
    "header": "{\\"X-Token\\":\\"{{'tk-' + (1 + 1)}}\\"}",
    "searchUrl": "@js:'/search?key=' + encodeURIComponent(result)",
    "ruleSearch": {
      "bookList": "class.result",
      "name": "class.name@text",
      "author": "class.author@text",
      "bookUrl": "class.name@href"
    },
    "ruleBookInfo": {
      "name": "class.bookname@text",
      "tocUrl": "class.toc@href",
      "intro": "@js:'JS简介:' + result"
    },
    "ruleToc": {
      "chapterList": "id.list@a",
      "chapterName": "@js:'JS章节:' + result",
      "chapterUrl": "href"
    },
    "ruleContent": {
      "content": "@js:java.ajax(baseUrl)"
    }
  }
]
''';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockSite site;
  late BookSource source;

  setUpAll(() async {
    site = await MockSite.start(port: 8791);
    final List<BookSource> list = SourceRepo.parseSources(_sourceJson(site.url));
    expect(list.length, 1);
    source = list.first;
  });

  tearDownAll(() async {
    await site.close();
  });

  testWidgets('JS searchUrl / JS 规则取字段', (WidgetTester tester) async {
    final SourceEngine engine = SourceEngine();
    try {
      final List<SearchBook> books = await engine.search(source, '仙侠');
      expect(books.length, 3);
      expect(books.first.name, '仙侠 之书 1');
      expect(books.first.bookUrl, '${site.url}/book/1');

      final BookInfo info = await engine.bookInfo(source, books.first.bookUrl);
      expect(info.name, '测试之书 1');
      expect(info.intro, startsWith('JS简介:'));
      expect(info.tocUrl, '${site.url}/toc/1');

      final List<BookChapter> chapters = await engine.chapters(source, info);
      expect(chapters.length, 12);
      expect(chapters.first.title, contains('JS章节:'));
      expect(chapters.first.url, '${site.url}/read/1/1');
    } finally {
      engine.dispose();
    }
  });

  testWidgets('JS 正文规则里用 java.ajax 取页面', (WidgetTester tester) async {
    final SourceEngine engine = SourceEngine();
    try {
      final BookContent content = await engine.content(
        source,
        BookChapter(title: '第 1 章', url: '${site.url}/read/1/1', index: 0),
      );
      final String plain = htmlToPlainText(content.text);
      expect(plain, contains('第 1 章'));
    } finally {
      engine.dispose();
    }
  });
}
