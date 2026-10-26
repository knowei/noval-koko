import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noval/src/net/http_service.dart';

/// 包子漫画：落盘 详情页/目录页/接口原始响应，便于修规则。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('baozimh dump', (WidgetTester tester) async {
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

    const String slug = 'douluodalu-fengxuandongman';

    final String manga = (await http.request(
      'https://baozimh.org/manga/$slug',
      headers: hdr,
      charset: 'utf-8',
    ))
        .body;
    File('tool/bz_manga2.html').writeAsStringSync(manga);
    say('manga len=${manga.length}');
    final RegExp h1 = RegExp(r'<h1[^>]*>([\s\S]*?)</h1>');
    say('h1: ${h1.firstMatch(manga)?.group(1)?.replaceAll(RegExp('<[^>]+>'), '|')}');
    for (final RegExpMatch m in RegExp(r'<meta[^>]+property="og:[^"]+"[^>]*>').allMatches(manga)) {
      say('meta: ${m.group(0)}');
    }
    final List<String> imgs =
        RegExp(r'<img[^>]+>').allMatches(manga).map((RegExpMatch m) => m.group(0)!).toList();
    say('imgs=${imgs.length}');
    for (final String i in imgs.take(6)) {
      say('  img ${i.length > 160 ? i.substring(0, 160) : i}');
    }

    final String toc = (await http.request(
      'https://baozimh.org/chapterlist/$slug',
      headers: hdr,
      charset: 'utf-8',
    ))
        .body;
    File('tool/bz_toc2.html').writeAsStringSync(toc);
    say('toc len=${toc.length}');
    final RegExp midQ = RegExp(r'data-mid="?(\d+)"?');
    say('data-mid(quoted|bare)=${midQ.firstMatch(toc)?.group(0)}');
    final int iMid = toc.indexOf('data-mid');
    if (iMid > 0) say('around data-mid: ${toc.substring(iMid - 80, (iMid + 120).clamp(0, toc.length)).replaceAll('\n', ' ')}');

    final RegExpMatch? mid = midQ.firstMatch(toc);
    if (mid != null) {
      final String api = (await http.request(
        'https://v2.apikk.top/api/manga/get?mid=${mid.group(1)}&mode=all',
        headers: hdr,
        charset: 'utf-8',
      ))
          .body;
      File('tool/bz_api2.json').writeAsStringSync(api);
      say('api len=${api.length} head=${api.substring(0, (api.length < 300) ? api.length : 300)}');
    }

    File('tool/bz_dump.txt').writeAsStringSync(log.toString());
  }, timeout: const Timeout(Duration(minutes: 5)));
}
