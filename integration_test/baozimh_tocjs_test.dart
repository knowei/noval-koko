import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noval/src/net/http_service.dart';
import 'package:noval/src/rule/rule_context.dart';
import 'package:noval/src/source/source_engine.dart';

/// 直接跑包子漫画的 chapterList JS 规则，看返回什么 / 抛什么错。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('baozimh toc js', (WidgetTester tester) async {
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

    final String toc = (await http.request(
      'https://baozimh.org/chapterlist/douluodalu-fengxuandongman',
      headers: hdr,
      charset: 'utf-8',
    ))
        .body;

    final SourceEngine engine = SourceEngine(http: http);
    final RuleContext ctx = RuleContext(
      node: null,
      pageHtml: toc,
      baseUrl: 'https://baozimh.org/manga/douluodalu-fengxuandongman',
      sourceUrl: 'https://baozimh.org',
      sourceName: '包子漫画',
      headers: hdr,
    );

    try {
      final List<String> parts = await engine.js.run(
        r'''var m = /data-mid="(\d+)"/.exec(result); (m ? m[1] : 'NO-MID');''',
        result: toc,
        baseUrl: 'https://baozimh.org/manga/douluodalu-fengxuandongman',
        sourceUrl: 'https://baozimh.org',
        sourceName: '包子漫画',
        headers: hdr,
      );
      say('mid=${parts.join("|")}');
    } catch (e) {
      say('mid ERR $e');
    }

    const String rule = r'''@js:(function () {
var slug = baseUrl.split('/').pop();
var m = /data-mid="(\d+)"/.exec(result);
if (!m) { return ''; }
var raw = java.ajax('https://v2.apikk.top/api/manga/get?mid=' + m[1] + '&mode=all');
var o = JSON.parse(raw);
var list = (o && o.data && o.data.chapters) || [];
var out = [];
for (var i = 0; i < list.length; i++) {
  var a = list[i].attributes || {};
  if (!a.slug) { continue; }
  out.push('<a href="/manga/' + slug + '/' + a.slug + '">' + (a.title || ('c' + i)) + '</a>');
}
out.join('');
})()''';
    try {
      final List<dynamic> items = await engine.parser.evalList(rule, ctx);
      say('items=${items.length}');
      for (final dynamic i in items.take(3)) {
        final String s = i.toString();
        say('  item len=${s.length} head=${s.substring(0, s.length < 140 ? s.length : 140)}');
      }
    } catch (e) {
      say('rule ERR $e');
    }

    File('tool/bz_toc_js.txt').writeAsStringSync(log.toString());
  }, timeout: const Timeout(Duration(minutes: 5)));
}
