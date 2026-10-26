import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noval/src/net/http_service.dart';

/// 判定 SF轻小说 正文到底能不能取：换 Referer、换书、换条目。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SF 正文可达性', (WidgetTester tester) async {
    final HttpService http = HttpService();
    const String ua =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
    final StringBuffer log = StringBuffer();

    Future<String> fetch(String url, Map<String, String> hdr) async {
      final HttpResult r =
          await http.request(url, headers: hdr, charset: 'utf-8');
      return r.body;
    }

    String brief(String h) {
      final String t =
          RegExp(r'<title>([\s\S]*?)</title>').firstMatch(h)?.group(1) ?? '';
      final int bi = h.indexOf('ChapterBody');
      return 'len=${h.length} title=$t bodyAt=$bi';
    }

    const String chapUrl =
        'https://book.sfacg.com/Novel/261860/387699/3307938/';

    final Map<String, Map<String, String>> variants = <String, Map<String, String>>{
      'ref-book': <String, String>{
        'User-Agent': ua,
        'Referer': 'https://book.sfacg.com/Novel/261860/',
      },
      'ref-toc': <String, String>{
        'User-Agent': ua,
        'Referer': 'https://book.sfacg.com/Novel/261860/MainIndex/',
      },
      'no-ref': <String, String>{'User-Agent': ua},
      'mobile': <String, String>{
        'User-Agent':
            'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) '
                'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 '
                'Mobile/15E148 Safari/604.1',
      },
    };
    for (final MapEntry<String, Map<String, String>> e in variants.entries) {
      try {
        final String h = await fetch(chapUrl, e.value);
        log.writeln('${e.key}: ${brief(h)}');
      } catch (err) {
        log.writeln('${e.key}: ERR $err');
      }
    }

    // 换一本书：搜索另一关键词
    for (final String kw in <String>['史莱姆', '剑来', '青春']) {
      try {
        final String s = await fetch(
            'http://s.sfacg.com/?Key=${Uri.encodeQueryComponent(kw)}&S=1&SS=0',
            <String, String>{'User-Agent': ua, 'Referer': 'https://book.sfacg.com/'});
        final List<String> books = RegExp(r'href="(https?://book\.sfacg\.com/[^"]*?/\d+)"')
            .allMatches(s)
            .map((RegExpMatch m) => m.group(1)!)
            .toSet()
            .toList();
        log.writeln('search [$kw] len=${s.length} books=${books.length} ${books.take(3)}');
        if (books.isEmpty) continue;
        final String b = books.first;
        final String toc = await fetch(
            '$b/MainIndex/',
            <String, String>{'User-Agent': ua, 'Referer': b});
        final List<String> cs = RegExp(r'href="([^"]*?/Novel/\d+/\d+/\d+/)"')
            .allMatches(toc)
            .map((RegExpMatch m) => m.group(1)!)
            .toSet()
            .toList();
        log.writeln('  toc ${brief(toc)} chapters=${cs.length}');
        if (cs.isEmpty) continue;
        String cu = cs.first;
        if (cu.startsWith('/')) cu = 'https://book.sfacg.com$cu';
        final String c = await fetch(cu, <String, String>{
          'User-Agent': ua,
          'Referer': '$b/MainIndex/',
        });
        log.writeln('  chap $cu -> ${brief(c)}');
        final int i = c.indexOf('ChapterBody');
        if (i > 0) {
          log.writeln('  snip=${c.substring(i, (i + 200).clamp(0, c.length)).replaceAll('\n', ' ')}');
        }
      } catch (err) {
        log.writeln('search [$kw] ERR $err');
      }
    }

    File('tool/sf_probe4.txt').writeAsStringSync(log.toString());
  }, timeout: const Timeout(Duration(minutes: 6)));
}
