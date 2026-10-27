import 'package:flutter_test/flutter_test.dart';
import 'package:noval/src/rule/rule_context.dart';
import 'package:noval/src/rule/rule_parser.dart';

const String _apiJson = '''
{"result":"ok","data":[
  {"id":"a1","attributes":{"title":"A 作品","pages":37},"externalUrl":null},
  {"id":"a2","attributes":{"title":"B 作品","pages":0},"externalUrl":"https://ext.example/x"}
]}
''';

void main() {
  test('接口返回 JSON 时，@Json 规则能直接取列表', () async {
    final RuleContext ctx = RuleContext.page(_apiJson, baseUrl: 'https://api.example');
    final RuleParser parser = RuleParser();

    final List<dynamic> items = await parser.evalList(r'@Json:$.data[*]', ctx);
    expect(items.length, 2);

    final RuleContext first = ctx.child(items.first);
    expect(await parser.evalString(r'@Json:$.attributes.title', first), 'A 作品');
    expect(await parser.evalString(r'@Json:$.id', first), 'a1');
  });

  // 注：`@js:` 规则要在 integration_test 里才能跑（QuickJS 的 dll 在纯单测进程里加载不到），
  // JSON 上下文里的 JS 取数由 integration_test/mangadex_test.dart 覆盖。

  test('HTML 页面没被 JSON 化，CSS 规则照常工作', () async {
    const String html = '<html><body><div class="x"><a href="/b/1">书名</a></div></body></html>';
    final RuleContext ctx = RuleContext.page(html, baseUrl: 'https://site.example');
    final RuleParser parser = RuleParser();
    final List<dynamic> items = await parser.evalList(r'@css:.x', ctx);
    expect(items.length, 1);
    final RuleContext c = ctx.child(items.first);
    expect(await parser.evalString(r'@css:a@text', c), '书名');
  });
}
