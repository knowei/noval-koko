import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noval/src/net/http_service.dart';

/// 把 SF 目录页/章节页原样存到 tool/ 下，方便结构化分析。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SF 落盘探针', (WidgetTester tester) async {
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
      // ignore: avoid_print
      print('$url -> ${r.statusCode} ${r.body.length} ${r.url}');
      return r.body;
    }

    final String toc =
        await fetch('https://book.sfacg.com/Novel/261860/MainIndex/');
    File('tool/sf_toc.html').writeAsStringSync(toc);
    final RegExp href = RegExp(r'href="([^"]+)"');
    final List<String> hs =
        href.allMatches(toc).map((RegExpMatch m) => m.group(1)!).toList();
    File('tool/sf_toc_links.txt').writeAsStringSync(hs.join('\n'));
    // ignore: avoid_print
    print('hrefs=${hs.length}');
    for (final String h in hs.take(40)) {
      // ignore: avoid_print
      print('  $h');
    }

    final String chap =
        await fetch('https://book.sfacg.com/Novel/261860/3152356/');
    File('tool/sf_chap.html').writeAsStringSync(chap);
    // ignore: avoid_print
    print('chap title=${RegExp(r'<title>([\s\S]*?)</title>').firstMatch(chap)?.group(1)}');
    // ignore: avoid_print
    print('chap body-len=${chap.length}');
  }, timeout: const Timeout(Duration(minutes: 4)));
}
