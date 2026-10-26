import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noval/src/net/http_service.dart';
import 'package:noval/src/source/source_engine.dart';

/// 试验：在 QuickJS 里跑包子漫画的 chapter-decoder.js，把加密的 images 解成 URL 数组。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('baozimh decoder', (WidgetTester tester) async {
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

    final String api = (await http.request(
      'https://v2.apikk.top/api/v2/chapter/getinfo?m=133&c=1643598',
      headers: hdr,
      charset: 'utf-8',
    ))
        .body;
    final Map<String, dynamic> json = jsonDecode(api) as Map<String, dynamic>;
    final Map<String, dynamic> info =
        (json['data'] as Map<String, dynamic>)['info'] as Map<String, dynamic>;
    final Map<String, dynamic> images = info['images'] as Map<String, dynamic>;
    final String payload = images['images'] as String;
    say('payload len=${payload.length} head=${payload.substring(0, 40)}');
    say('info keys=${info.keys.toList()}');

    final String decoder = (await http.request(
      'https://baozimh.org/assets/runtime/chapter-decoder.js',
      headers: hdr,
      charset: 'utf-8',
    ))
        .body;
    say('decoder len=${decoder.length}');

    final SourceEngine engine = SourceEngine(http: http);

    String shim() => r'''
var window = {};
var self = {};
var atob = function (s) {
  var chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
  var str = String(s).replace(/=+$/, '');
  var out = '';
  var bc = 0, bs = 0, buffer, idx = 0;
  while ((buffer = str.charAt(idx++))) {
    buffer = chars.indexOf(buffer);
    if (buffer === -1) { continue; }
    bs = bc % 4 ? bs * 64 + buffer : buffer;
    if (bc++ % 4) { out += String.fromCharCode(255 & (bs >> ((-2 * bc) & 6))); }
  }
  return out;
};
var TextDecoder = function () {
  this.decode = function (bytes) {
    var out = '';
    for (var i = 0; i < bytes.length; i++) {
      out += String.fromCharCode(bytes[i]);
    }
    return out;
  };
};
var __decoder = '';''';

    final StringBuffer code = StringBuffer()
      ..writeln(shim())
      ..writeln('__decoder = ${jsonEncode(decoder)};')
      ..writeln('eval(__decoder);')
      ..writeln('if (window.__cimg && window.__cimg.r) { ["HAVE-R"]; } else { ["NO-R"]; }');

    try {
      final List<String> r = await engine.js.run(
        code.toString(),
        result: '',
        baseUrl:
            'https://baozimh.org/manga/douluodalu-fengxuandongman/133-6572120-302',
        sourceUrl: 'https://baozimh.org',
        sourceName: '包子漫画',
        headers: hdr,
      );
      say('step1 -> ${r.join(" | ")}');
    } catch (e) {
      say('step1 ERR $e');
    }

    final StringBuffer code2 = StringBuffer()
      ..writeln(shim())
      ..writeln('__decoder = ${jsonEncode(decoder)};')
      ..writeln('eval(__decoder);')
      ..writeln('var __out = [];')
      ..writeln('try {')
      ..writeln('  var __res = window.__cimg.r(${jsonEncode(payload)});')
      ..writeln('  __out = Array.isArray(__res) ? __res.map(function (x) { return String(x); }) : [String(__res)];')
      ..writeln('} catch (e) { __out = ["ERR:" + e]; }')
      ..writeln('__out;');
    try {
      final List<String> r2 = await engine.js.run(
        code2.toString(),
        result: '',
        baseUrl:
            'https://baozimh.org/manga/douluodalu-fengxuandongman/133-6572120-302',
        sourceUrl: 'https://baozimh.org',
        sourceName: '包子漫画',
        headers: hdr,
      );
      say('decoded ${r2.length}');
      for (final String u in r2.take(6)) {
        say('   $u');
      }
    } catch (e) {
      say('decode ERR $e');
    }

    File('tool/bz_decoder_try.txt').writeAsStringSync(log.toString());
  }, timeout: const Timeout(Duration(minutes: 6)));
}
