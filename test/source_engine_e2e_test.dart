import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noval/src/model/book_info.dart';
import 'package:noval/src/model/book_source.dart';
import 'package:noval/src/model/search_book.dart';
import 'package:noval/src/source/source_engine.dart';
import 'package:noval/src/ui/reader/read_theme.dart';

/// 端到端测试：本地起一个假站点，用 Legado 格式的书源规则去抓。
/// 验证「规则 → HTTP → 选择器 → 数据」整条链路，不依赖外网。
void main() {
  late HttpServer server;
  late String base;

  const String searchHtml = '''
<html><body>
<div class="result">
  <a class="name" href="/book/1">测试之书</a>
  <span class="author">作者甲</span>
  <span class="kind">玄幻</span>
  <img class="cover" src="/img/1.jpg">
  <p class="intro">这是一本测试用的书</p>
  <span class="last">第二章 继续</span>
</div>
<div class="result">
  <a class="name" href="/book/1">测试之书（重复）</a>
  <span class="author">作者甲</span>
</div>
<div class="result">
  <a class="name" href="/book/2">第二本书</a>
  <span class="author">作者乙</span>
</div>
</body></html>
''';

  const String infoHtml = '''
<html><body>
<h1 class="bookname">测试之书</h1>
<span class="author">作者甲</span>
<div class="intro">简介：很长很长的简介</div>
<img class="cover" src="/img/1.jpg">
<a class="toc" href="/toc/1">查看目录</a>
</body></html>
''';

  const String tocHtml = '''
<html><body>
<div id="list">
  <a href="/read/1">第一章 开端</a>
  <a href="/read/2">第二章 继续</a>
  <a href="/read/3">第三章 结束</a>
</div>
</body></html>
''';

  const String readHtml = '''
<html><body>
<div id="content"><p>第一段正文。</p><p>第二段正文&amp;符号。</p></div>
</body></html>
''';

  const String comicHtml = '''
<html><body>
<div id="content">
  <img class="pic" src="/i/1.jpg">
  <img class="pic" src="/i/2.jpg">
</div>
</body></html>
''';

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    server.listen((HttpRequest req) async {
      final HttpResponse res = req.response;
      res.headers.contentType = ContentType('text', 'html', charset: 'utf-8');
      final String path = req.uri.path;
      String body;
      if (path == '/search') {
        body = searchHtml;
      } else if (path == '/book/1') {
        body = infoHtml;
      } else if (path == '/toc/1') {
        body = tocHtml;
      } else if (path.startsWith('/read/')) {
        body = readHtml;
      } else if (path == '/comic/1') {
        body = comicHtml;
      } else {
        res.statusCode = 404;
        body = 'not found';
      }
      res.write(body);
      await res.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  Map<String, dynamic> novelSourceJson() => <String, dynamic>{
        'bookSourceName': '本地测试',
        'bookSourceUrl': base,
        'bookSourceType': 0,
        'searchUrl': '/search?key={{key}}',
        'ruleSearch': <String, dynamic>{
          'bookList': 'class.result',
          'name': 'class.name@text',
          'author': 'class.author@text',
          'kind': 'class.kind@text',
          'intro': 'class.intro@text',
          'coverUrl': 'class.cover@src',
          'bookUrl': 'class.name@href',
          'lastChapter': 'class.last@text',
        },
        'ruleBookInfo': <String, dynamic>{
          'name': 'class.bookname@text',
          'author': 'class.author@text',
          'intro': 'class.intro@text',
          'coverUrl': 'class.cover@src',
          'tocUrl': 'class.toc@href',
        },
        'ruleToc': <String, dynamic>{
          'chapterList': 'id.list@a',
          'chapterName': 'text',
          'chapterUrl': 'href',
        },
        'ruleContent': <String, dynamic>{
          'content': 'id.content@html',
        },
      };

  test('小说：搜索 → 详情 → 目录 → 正文', () async {
    final BookSource source =
        BookSource.fromJson(novelSourceJson());
    final SourceEngine engine = SourceEngine();

    try {
      expect(source.canSearch, isTrue);

      final List<SearchBook> books = await engine.search(source, '测试');
      // 重复 bookUrl 会被去重
      expect(books.length, 2);
      expect(books.first.name, '测试之书');
      expect(books.first.author, '作者甲');
      expect(books.first.kind, '玄幻');
      expect(books.first.intro, '这是一本测试用的书');
      expect(books.first.bookUrl, '$base/book/1');
      expect(books.first.cover, '$base/img/1.jpg');
      expect(books.first.lastChapter, '第二章 继续');

      final BookInfo info = await engine.bookInfo(source, books.first.bookUrl);
      expect(info.name, '测试之书');
      expect(info.author, '作者甲');
      expect(info.tocUrl, '$base/toc/1');

      final List<BookChapter> chapters = await engine.chapters(source, info);
      expect(chapters.length, 3);
      expect(chapters.first.title, '第一章 开端');
      expect(chapters[1].url, '$base/read/2');

      final BookContent content = await engine.content(source, chapters[1]);
      expect(content.text, contains('<p>'));
      final String plain = htmlToPlainText(content.text);
      expect(plain, contains('第一段正文'));
      expect(plain, contains('第二段正文&符号'));
      expect(content.images, isEmpty);
    } finally {
      engine.dispose();
    }
  });

  test('漫画：正文规则解析出图片列表', () async {
    final Map<String, dynamic> json = novelSourceJson();
    json['bookSourceName'] = '本地漫画';
    json['bookSourceType'] = SourceType.image;
    json['ruleContent'] = <String, dynamic>{'content': 'class.pic@src'};

    final BookSource source = BookSource.fromJson(json);
    final SourceEngine engine = SourceEngine();

    try {
      expect(source.isComic, isTrue);
      final BookContent content = await engine.content(
        source,
        BookChapter(title: '第1话', url: '$base/comic/1', index: 0),
      );
      expect(content.images, <String>['$base/i/1.jpg', '$base/i/2.jpg']);
    } finally {
      engine.dispose();
    }
  });

  test('XPath 规则与文本替换', () async {
    final Map<String, dynamic> json = novelSourceJson();
    json['ruleSearch'] = <String, dynamic>{
      'bookList': r'@XPath://div[@class="result"]',
      'name': r'@XPath:.//a[@class="name"]/text()',
      'bookUrl': r'@XPath:.//a[@class="name"]/@href',
      'author': r'@XPath:.//span[@class="author"]/text()##作者##',
    };

    final BookSource source = BookSource.fromJson(json);
    final SourceEngine engine = SourceEngine();

    try {
      final List<SearchBook> books = await engine.search(source, 'x');
      expect(books, isNotEmpty);
      expect(books.first.name, '测试之书');
      expect(books.first.bookUrl, '$base/book/1');
      expect(books.first.author, '甲');
    } finally {
      engine.dispose();
    }
  });

  test('书源 JSON 反序列化保持规则', () {
    final String text = jsonEncode(<Map<String, dynamic>>[novelSourceJson()]);
    final Object? decoded = jsonDecode(text);
    final BookSource source = BookSource.fromJson(
      (decoded! as List<dynamic>).first as Map<String, dynamic>,
    );
    expect(source.name, '本地测试');
    expect(source.url, base);
    expect(source.ruleToc.chapterList, 'id.list@a');
    expect(source.ruleContent.content, 'id.content@html');
    expect(source.enabled, isTrue);
  });
}
