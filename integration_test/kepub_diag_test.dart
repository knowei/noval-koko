// 诊断：kepub 章节页「下一章」解析
// 跑法：flutter test integration_test/kepub_diag_test.dart -d windows
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noval/src/model/book_source.dart';
import 'package:noval/src/net/http_service.dart';
import 'package:noval/src/rule/rule_context.dart';
import 'package:noval/src/rule/rule_parser.dart';

void main() {
  final BookSource source = BookSource.fromJson(
    jsonDecode(File('sample_sources/kepub.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  test('章节页 selector 诊断', () async {
    final HttpService http = HttpService(timeout: const Duration(seconds: 25));
    const String url = 'https://www.kepub.net/book/10044/10001';
    final HttpResult res = await http.request(url, headers: <String, String>{
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
          'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      'Accept-Language': 'zh-CN,zh;q=0.9',
    });
    final String body = res.body;
    final RuleContext ctx = RuleContext.page(
      body,
      baseUrl: url,
      sourceUrl: source.url,
      sourceName: source.name,
    );
    final RuleParser parser = RuleParser();
    final StringBuffer log = StringBuffer('page ${body.length} chars\n');

    for (final String rule in <String>[
      '@css:div.next_chapter a@href',
      '@css:#change_chapter_block a@href',
      '@css:a[href^="/book/10044/"]@href',
      'text.下一章@href',
      '@css:a@text',
    ]) {
      try {
        final List<String> v = (await parser.evalList(rule, ctx))
            .map((dynamic e) => e.toString())
            .toList();
        log.writeln('$rule -> n=${v.length} '
            '${v.take(3).map((String s) => s.length > 60 ? '${s.substring(0, 60)}…' : s).toList()}');
      } catch (e) {
        log.writeln('$rule -> EXC $e');
      }
      try {
        final String u = await parser.evalUrl(rule, ctx);
        log.writeln('    evalUrl -> "$u"');
      } catch (e) {
        log.writeln('    evalUrl -> EXC $e');
      }
    }
    log.writeln('next_chapter 出现=${body.split('next_chapter').length - 1}');
    log.writeln(
        'change_chapter_block 出现=${body.split('change_chapter_block').length - 1}');
    File('tool/kepub_diag.txt').writeAsStringSync(log.toString());
  }, timeout: const Timeout(Duration(minutes: 3)));
}
