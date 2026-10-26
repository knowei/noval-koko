import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noval/src/net/http_service.dart';

/// 包子漫画章节页：确认 data-ms / data-cs 位置与图片接口。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('baozimh chapter', (WidgetTester tester) async {
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

    const String url =
        'https://baozimh.org/manga/douluodalu-fengxuandongman/133-6572120-302';
    final String html = (await http.request(url, headers: hdr, charset: 'utf-8')).body;
    File('tool/bz_chap2.html').writeAsStringSync(html);
    say('len=${html.length}');
    for (final String kw in <String>['chapterContent', 'data-ms', 'data-cs', 'chapcontent']) {
      final int i = html.indexOf(kw);
      say('$kw at=$i');
      if (i > 0) {
        say('  ctx=${html.substring((i - 80).clamp(0, html.length), (i + 220).clamp(0, html.length)).replaceAll('\n', ' ')}');
      }
    }

    final RegExpMatch? ms = RegExp(r'data-ms="?(\d+)"?').firstMatch(html);
    final RegExpMatch? cs = RegExp(r'data-cs="?(\d+)"?').firstMatch(html);
    say('ms=${ms?.group(1)} cs=${cs?.group(1)}');
    if (ms != null && cs != null) {
      final String api = (await http.request(
        'https://v2.apikk.top/api/v2/chapter/getinfo?m=${ms.group(1)}&c=${cs.group(1)}',
        headers: hdr,
        charset: 'utf-8',
      ))
          .body;
      File('tool/bz_chap_api.json').writeAsStringSync(api);
      say('api len=${api.length} head=${api.substring(0, api.length < 400 ? api.length : 400)}');
    }

    File('tool/bz_chap_dump.txt').writeAsStringSync(log.toString());
  }, timeout: const Timeout(Duration(minutes: 4)));
}
