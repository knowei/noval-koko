import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noval/src/net/http_service.dart';

/// 探测 SF 分卷页 / 章节页 / 可能的 JSON 接口。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SF 分卷与章节探针', (WidgetTester tester) async {
    final HttpService http = HttpService();
    const Map<String, String> hdr = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      'Referer': 'https://book.sfacg.com/',
    };
    final StringBuffer log = StringBuffer();

    Future<void> probe(String url, {String? save}) async {
      try {
        final HttpResult r =
            await http.request(url, headers: hdr, charset: 'utf-8');
        final String b = r.body;
        final String title =
            RegExp(r'<title>([\s\S]*?)</title>').firstMatch(b)?.group(1) ??
                '';
        final int cLinks = RegExp(r'/C/\d+').allMatches(b).length;
        final int novelLinks = RegExp(r'/Novel/261860/\d+/\d+/')
            .allMatches(b)
            .length;
        log.writeln('$url -> ${r.statusCode} len=${b.length} '
            'title=$title novelLinks=$novelLinks cLinks=$cLinks '
            'ChapterBody=${'ChapterBody'.allMatches(b).length}');
        // ignore: avoid_print
        print(log.toString().split('\n').last);
        if (save != null) File(save).writeAsStringSync(b);
      } catch (e) {
        log.writeln('$url -> ERR $e');
        // ignore: avoid_print
        print('$url -> ERR $e');
      }
    }

    await probe('https://book.sfacg.com/Novel/261860/387699/',
        save: 'tool/sf_vol1.html');
    await probe('https://book.sfacg.com/Novel/261860/389184/',
        save: 'tool/sf_vol2.html');
    await probe('https://book.sfacg.com/Novel/261860/387699/3307938/',
        save: 'tool/sf_chap1.html');
    await probe('https://book.sfacg.com/Novel/261860/MainIndex/?page=2');
    await probe('https://book.sfacg.com/Novel/261860/Index/');
    await probe('https://book.sfacg.com/ajax/novel/GetChapterList?novelId=261860');
    await probe('https://book.sfacg.com/Novel/261860/Catalog/');

    File('tool/sf_probe2.txt').writeAsStringSync(log.toString());
  }, timeout: const Timeout(Duration(minutes: 5)));
}
