import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noval/src/net/http_service.dart';

/// 探 SF：MainIndex 分页总数 + 多个章节可读性。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SF 分页与章节可读性', (WidgetTester tester) async {
    final HttpService http = HttpService();
    const Map<String, String> hdr = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      'Referer': 'https://book.sfacg.com/',
    };
    final StringBuffer log = StringBuffer();

    Future<String> fetch(String url) async {
      final HttpResult r =
          await http.request(url, headers: hdr, charset: 'utf-8');
      return r.body;
    }

    // 1) 分页上限
    final Set<String> chapters = <String>{};
    for (int p = 1; p <= 12; p++) {
      final String h =
          await fetch('https://book.sfacg.com/Novel/261860/MainIndex/?page=$p');
      final List<String> ls = RegExp(r'/(?:Novel/261860/)?(\d+/\d+)/"')
          .allMatches(h)
          .map((RegExpMatch m) => m.group(1)!)
          .toList();
      log.writeln('page $p len=${h.length} links=${ls.length}');
      chapters.addAll(ls);
      if (ls.isEmpty) break;
    }
    log.writeln('total unique chapters=${chapters.length}');

    // 2) 章节可读性抽查（首/中/尾）
    final List<String> all = chapters.toList();
    final List<int> idx = <int>[
      0,
      all.length ~/ 2,
      all.length - 1,
    ].where((int i) => i >= 0 && i < all.length).toList();
    for (final int i in idx) {
      final String path = all[i];
      final String h =
          await fetch('https://book.sfacg.com/Novel/261860/$path/');
      final String title =
          RegExp(r'<title>([\s\S]*?)</title>').firstMatch(h)?.group(1) ?? '';
      final int bodyIdx = h.indexOf('ChapterBody');
      String snippet = '';
      if (bodyIdx > 0) {
        snippet = h
            .substring(bodyIdx, (bodyIdx + 160).clamp(0, h.length))
            .replaceAll('\n', ' ');
      }
      log.writeln('chap[$i] $path len=${h.length} title=$title '
          'body=$bodyIdx snip=$snippet');
    }

    File('tool/sf_probe3.txt').writeAsStringSync(log.toString());
  }, timeout: const Timeout(Duration(minutes: 6)));
}
