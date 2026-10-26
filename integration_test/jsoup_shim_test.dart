import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noval/src/rule/js_engine.dart';

/// jsoup 垫片自测：`org.jsoup.Jsoup.parse(...)` 完全在 JS 侧完成，不联网。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  JsEngine newEngine() => JsEngine(
        fetch: (JsRequest request) async => '',
      );

  const String html = '''
<html><body>
  <div id="info" class="box main">
    <h1 class="title">剑来</h1>
    <span>作者：烽火戏诸侯</span>
    <a href="/book/1">详情</a>
  </div>
  <ul class="list">
    <li><a href="/read/1">第一章</a></li>
    <li><a href="/read/2">第二章</a></li>
    <li><a href="/read/3">第三章</a></li>
  </ul>
  <p>正文第一段 &amp; 转义</p>
</body></html>
''';

  testWidgets('jsoup：select / text / attr / 切片', (WidgetTester tester) async {
    final JsEngine engine = newEngine();

    final String title = await engine.runString(
      r"org.jsoup.Jsoup.parse(result).select('h1.title').text()",
      result: html,
      baseUrl: 'https://demo.test/book/1',
    );
    expect(title, '剑来');

    final String author = await engine.runString(
      r"org.jsoup.Jsoup.parse(result).select('#info span').text()",
      result: html,
    );
    expect(author, contains('烽火戏诸侯'));

    // jsoup 语义：attr('href') 返回原始值，需要绝对地址时用 abs:href
    final String href = await engine.runString(
      r"org.jsoup.Jsoup.parse(result).select('ul.list li a').attr('href')",
      result: html,
      baseUrl: 'https://demo.test/book/1',
    );
    expect(href, '/read/1');

    final String absHref = await engine.runString(
      r"org.jsoup.Jsoup.parse(result).select('ul.list li a').attr('abs:href')",
      result: html,
      baseUrl: 'https://demo.test/book/1',
    );
    expect(absHref, 'https://demo.test/read/1');

    final String absHref2 = await engine.runString(
      r"org.jsoup.Jsoup.parse(result).select('a').attr('abs:href')",
      result: html,
      baseUrl: 'https://demo.test/book/1',
    );
    expect(absHref2, 'https://demo.test/book/1');

    final String third = await engine.runString(
      r"org.jsoup.Jsoup.parse(result).select('ul.list li').get(2).text()",
      result: html,
    );
    expect(third, '第三章');

    final String size = await engine.runString(
      r"String(org.jsoup.Jsoup.parse(result).select('ul.list li').size())",
      result: html,
    );
    expect(size, '3');

    final String joined = await engine.runString(
      r"org.jsoup.Jsoup.parse(result).select('ul.list li').eachText().join('|')",
      result: html,
    );
    expect(joined, '第一章|第二章|第三章');

    final String p = await engine.runString(
      r"org.jsoup.Jsoup.parse(result).select('p').text()",
      result: html,
    );
    expect(p, '正文第一段 & 转义');
  });

  testWidgets('jsoup：属性选择器 / first / 取 html', (WidgetTester tester) async {
    final JsEngine engine = newEngine();

    final String byAttr = await engine.runString(
      r"org.jsoup.Jsoup.parse(result).select('a[href^=/read]').size() + ''",
      result: html,
    );
    expect(byAttr, '3');

    final String first = await engine.runString(
      r"org.jsoup.Jsoup.parse(result).select('li').first().text()",
      result: html,
    );
    expect(first, '第一章');

    final String htmlOfLi = await engine.runString(
      r"org.jsoup.Jsoup.parse(result).select('ul.list li').get(0).html()",
      result: html,
    );
    expect(htmlOfLi, contains('/read/1'));

    // 常见写法：先 select 再链式 select
    final String nested = await engine.runString(
      r"org.jsoup.Jsoup.parse(result).select('#info').select('a').text()",
      result: html,
    );
    expect(nested, '详情');
  });
}
