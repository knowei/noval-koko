// 本地假站点的服务实现（供 tool/mock_site.dart 与测试共用）。
import 'dart:convert';
import 'dart:io';

/// 一张 120x80 的纯色 PNG（硬编码，避免引入图像库）。
const String _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAHgAAABQCAIAAAA7XK6XAAAAY0lEQVR4nO3QMQEAAAjDMMC/56'
    'EBvyQK0rPTzMy8dwfgU4MWLNCCRVqwSAsWacEiLVikBYu0YJEWLNKCRVqwSAsWacEiLVikBYu0YJ'
    'EWLNKCRVqwSAsWacEiLVikBYu0YJEWLNKCRVqwSAvpgAsSAWNZAAAAAElFTkSuQmCC';

/// 启动假站点。`port` 传 0 表示随机端口（此时 [MockSite.url] 才有意义）。
class MockSite {
  MockSite._(this._server, this.port);

  final HttpServer _server;
  final int port;

  String get url => 'http://127.0.0.1:$port';

  static Future<MockSite> start({int port = 8787}) async {
    final HttpServer server =
        await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    final MockSite site = MockSite._(server, server.port);
    server.listen(site._handle);
    return site;
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest req) async {
    final HttpResponse res = req.response;
    final String path = req.uri.path;
    try {
      if (path == '/img/x.png' || path.startsWith('/i/')) {
        res.headers.contentType = ContentType('image', 'png');
        res.add(base64Decode(_pngBase64));
      } else {
        res.headers.contentType = ContentType('text', 'html', charset: 'utf-8');
        final Map<String, String> q = req.uri.queryParameters;
        res.write(render(
          path,
          q['key'] ?? '',
          comic: q['comic'] == '1',
        ));
      }
    } catch (e) {
      res.statusCode = 500;
      res.write('error: $e');
    }
    await res.close();
  }

  /// 按路径生成页面 HTML。
  static String render(String path, String key, {bool comic = false}) {
    if (path == '/search') {
      final String k = key.isEmpty ? '测试' : key;
      final String prefix = comic ? '/comic' : '/book';
      final String items = List<String>.generate(3, (int i) {
        final int id = i + 1;
        return '''
<div class="result">
  <a class="name" href="$prefix/$id">$k 之书 $id</a>
  <span class="author">作者$id</span>
  <span class="kind">玄幻</span>
  <img class="cover" src="/img/x.png">
  <p class="intro">这是《$k 之书 $id》的简介，用来测试规则解析。</p>
  <span class="last">第 20 章 终章</span>
</div>''';
      }).join();
      return _page('搜索：$k', items);
    }

    final RegExpMatch? book = RegExp(r'^/book/(\d+)$').firstMatch(path);
    if (book != null) {
      final String id = book.group(1)!;
      return _page('书籍 $id', '''
<h1 class="bookname">测试之书 $id</h1>
<span class="author">作者$id</span>
<img class="cover" src="/img/x.png">
<div class="intro">这是第 $id 本书的完整简介，包含若干文字用于测试简介解析与折叠展示。</div>
<a class="toc" href="/toc/$id">目录</a>''');
    }

    final RegExpMatch? toc = RegExp(r'^/toc/(\d+)$').firstMatch(path);
    if (toc != null) {
      final String id = toc.group(1)!;
      final String links = List<String>.generate(12, (int i) {
        final int n = i + 1;
        return '<a href="/read/$id/$n">第 $n 章 标题文字</a>';
      }).join();
      return _page('目录 $id', '<div id="list">$links</div>');
    }

    final RegExpMatch? read = RegExp(r'^/read/(\d+)/(\d+)$').firstMatch(path);
    if (read != null) {
      final String id = read.group(1)!;
      final String n = read.group(2)!;
      final StringBuffer sb =
          StringBuffer('<h2 class="ctitle">第 $n 章 标题文字</h2>');
      sb.write('<div id="content">');
      for (int i = 1; i <= 14; i++) {
        sb.write('<p>第 $n 章第 $i 段正文。这是本地假站点生成的测试内容，'
            '用来验证分页、翻页、字号行距与进度保存是否正常。</p>');
      }
      sb.write('</div>');
      sb.write('<a id="next" href="/read/$id/${int.parse(n) + 1}">下一章</a>');
      return _page('第 $n 章', sb.toString());
    }

    final RegExpMatch? comicToc = RegExp(r'^/comic-toc/(\d+)$').firstMatch(path);
    if (comicToc != null) {
      final String id = comicToc.group(1)!;
      return _page('漫画目录 $id', '''
<div id="list">
  <a href="/comic-read/$id/1">第 1 话 开始</a>
  <a href="/comic-read/$id/2">第 2 话 结束</a>
</div>''');
    }

    final RegExpMatch? comicRead =
        RegExp(r'^/comic-read/(\d+)/(\d+)$').firstMatch(path);
    if (comicRead != null) {
      final String id = comicRead.group(1)!;
      final String n = comicRead.group(2)!;
      final String imgs = List<String>.generate(5, (int i) {
        return '<img class="pic" src="/i/$id-$n-${i + 1}.png">';
      }).join();
      return _page('漫画 $id-$n', '<div id="content">$imgs</div>');
    }

    final RegExpMatch? comicBook =
        RegExp(r'^/comic/(\d+)$').firstMatch(path);
    if (comicBook != null) {
      final String id = comicBook.group(1)!;
      return _page('漫画 $id', '''
<h1 class="bookname">漫画测试 $id</h1>
<span class="author">漫画家$id</span>
<img class="cover" src="/img/x.png">
<div class="intro">竖屏条漫测试，每话 5 张图。</div>
<a class="toc" href="/comic-toc/$id">目录</a>''');
    }

    return _page(
      '本地假站点',
      '''
<h1>mock site is running</h1>
<ul>
  <li><a href="/search?key=%E6%B5%8B%E8%AF%95">搜索「测试」</a></li>
  <li><a href="/book/1">书籍 1</a></li>
  <li><a href="/comic/1">漫画 1</a></li>
</ul>
<p>把 docs/mock_source.json 导入 App 的「书源」页即可。</p>''',
    );
  }

  static String _page(String title, String body) => '''
<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8"><title>$title</title></head>
<body><h1>$title</h1>
$body
<footer><p>mock site</p></footer>
</body></html>''';
}
