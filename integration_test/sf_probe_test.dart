import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noval/src/net/http_service.dart';

/// 用 App 自己的 Dio 栈探 SF轻小说 详情/目录/章节页结构。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SF 结构探针', (WidgetTester tester) async {
    final StringBuffer log = StringBuffer();
    void say(Object? s) {
      log.writeln(s);
      // ignore: avoid_print
      print(s);
    }

    final HttpService http = HttpService();
    const Map<String, String> hdr = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      'Referer': 'https://book.sfacg.com/',
    };

    Future<String> fetch(String url) async {
      final HttpResult r =
          await http.request(url, headers: hdr, charset: 'utf-8');
      return r.body;
    }

    const String book = 'https://book.sfacg.com/Novel/261860/';
    final String bookHtml = await fetch(book);
    say('book len=${bookHtml.length}');
    say('book MainIndex=${bookHtml.contains('MainIndex')}');
    say('book catalog-list=${'catalog-list'.allMatches(bookHtml).length}');
    say('book /C/=${'/C/'.allMatches(bookHtml).length}');

    const String toc = 'https://book.sfacg.com/Novel/261860/MainIndex/';
    final String tocHtml = await fetch(toc);
    say('toc len=${tocHtml.length}');
    say('toc catalog-list=${'catalog-list'.allMatches(tocHtml).length}');
    say('toc /C/=${'/C/'.allMatches(tocHtml).length}');
    say('toc li=${'<li'.allMatches(tocHtml).length}');
    final RegExp cLink = RegExp(r'href="([^"]*?/C/\d+[^"]*)"');
    final List<String> links = cLink
        .allMatches(tocHtml)
        .map((RegExpMatch m) => m.group(1)!)
        .toList();
    say('toc C links=${links.length}');
    for (final String u in links.take(5)) {
      say('  $u');
    }
    say('toc has nextpage=${tocHtml.contains('下一页')}');
    say('toc has ajax=${tocHtml.contains('ajax')}');

    String chapUrl = links.isNotEmpty
        ? links.first
        : 'https://book.sfacg.com/Novel/261860/3152356/';
    if (chapUrl.startsWith('/')) chapUrl = 'https://book.sfacg.com$chapUrl';
    say('chap url=$chapUrl');
    final String chap = await fetch(chapUrl);
    say('chap len=${chap.length}');
    say('chap ChapterBody=${'ChapterBody'.allMatches(chap).length}');
    final int i = chap.indexOf('ChapterBody');
    if (i >= 0) {
      say('chap snippet=${chap.substring(i, (i + 220).clamp(0, chap.length)).replaceAll('\n', ' ')}');
    }
    say('chap has nextchapter=${chap.contains('下一章')}');

    File('tool/sf_probe_report.txt').writeAsStringSync(log.toString());
  }, timeout: const Timeout(Duration(minutes: 4)));
}
