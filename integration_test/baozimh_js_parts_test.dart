import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noval/src/net/http_service.dart';
import 'package:noval/src/rule/rule_context.dart';
import 'package:noval/src/source/source_engine.dart';

/// 逐段确认：ajax 能不能取到 apikk 接口 / chapters 数量 / 字符串返回值是否被当成列表。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('baozimh js 分段', (WidgetTester tester) async {
    final HttpService http = HttpService();
    const Map<String, String> hdr = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      'Referer': 'https://baozimh.org/',
    };
    final StringBuffer log = StringBuffer();
    void say(Object? s) {
      log.writeln(s);
      // ignore: avoid_print
      print(s);
    }

    final SourceEngine engine = SourceEngine(http: http);
    const String base = 'https://baozimh.org/manga/douluodalu-fengxuandongman';

    Future<void> probe(String name, String code) async {
      try {
        final List<String> parts = await engine.js.run(
          code,
          result: '',
          baseUrl: base,
          sourceUrl: 'https://baozimh.org',
          sourceName: '包子漫画',
          headers: hdr,
        );
        say('$name -> ${parts.length} part(s)');
        for (final String p in parts.take(4)) {
          say('   ${p.length > 160 ? p.substring(0, 160) : p}');
        }
      } catch (e) {
        say('$name ERR $e');
      }
    }

    await probe('plain-string', r'''['hello', 'world'];''');
    await probe('ajax-len', r'''
var raw = java.ajax('https://v2.apikk.top/api/manga/get?mid=133&mode=all');
['len=' + raw.length, raw.slice(0, 40)];
''');
    await probe('chapters-count', r'''
var raw = java.ajax('https://v2.apikk.top/api/manga/get?mid=133&mode=all');
var o = JSON.parse(raw);
var list = (o && o.data && o.data.chapters) || [];
['n=' + list.length, String(list.length ? list[0].attributes.slug : 'none')];
''');
    await probe('joined-html', r'''
var raw = java.ajax('https://v2.apikk.top/api/manga/get?mid=133&mode=all');
var o = JSON.parse(raw);
var list = (o && o.data && o.data.chapters) || [];
var out = [];
for (var i = 0; i < Math.min(list.length, 3); i++) {
  var a = list[i].attributes || {};
  out.push('<a href="/manga/x/' + a.slug + '">' + a.title + '</a>');
}
out.join('');
''');

    // 用 parser 看字符串型 @js 结果如何被列表化
    final RuleContext ctx = RuleContext(
      pageHtml: '',
      baseUrl: base,
      sourceUrl: 'https://baozimh.org',
      sourceName: '包子漫画',
      headers: hdr,
    );
    try {
      final List<dynamic> items = await engine.parser.evalList(
        r'''@js:(function(){var raw = java.ajax('https://v2.apikk.top/api/manga/get?mid=133&mode=all');
var o = JSON.parse(raw); var list = (o && o.data && o.data.chapters) || [];
var out = []; for (var i = 0; i < Math.min(list.length, 3); i++) { var a = list[i].attributes || {};
out.push('<a href="/manga/x/' + a.slug + '">' + a.title + '</a>'); } out.join('');})()''',
        ctx,
      );
      say('evalList(string) -> ${items.length}');
      for (final dynamic i in items.take(2)) {
        say('   ${i.toString().substring(0, 140.clamp(0, i.toString().length))}');
      }
    } catch (e) {
      say('evalList(string) ERR $e');
    }

    try {
      final List<dynamic> items2 = await engine.parser.evalList(
        r'''@js:(function(){var raw = java.ajax('https://v2.apikk.top/api/manga/get?mid=133&mode=all');
var o = JSON.parse(raw); var list = (o && o.data && o.data.chapters) || [];
var out = []; for (var i = 0; i < Math.min(list.length, 3); i++) { var a = list[i].attributes || {};
out.push('<a href="/manga/x/' + a.slug + '">' + a.title + '</a>'); } return out;})()''',
        ctx,
      );
      say('evalList(array) -> ${items2.length}');
      for (final dynamic i in items2.take(2)) {
        say('   ${i.toString().substring(0, 140.clamp(0, i.toString().length))}');
      }
    } catch (e) {
      say('evalList(array) ERR $e');
    }

    File('tool/bz_js_parts.txt').writeAsStringSync(log.toString());
  }, timeout: const Timeout(Duration(minutes: 6)));
}
