import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noval/src/core/text_util.dart';
import 'package:noval/src/model/book_source.dart';
import 'package:noval/src/net/http_service.dart';
import 'package:noval/src/source/source_engine.dart';

/// 扫 GitHub 上收集到的漫画源：挨个跑「搜索 → 详情 → 目录 → 正文图片」，
/// 把真正能取到图的挑出来。
///
/// 跑法：
///   flutter test integration_test/manga_scan_test.dart -d windows
/// 结果写到 tool/manga_scan_report.txt（人看的）和 tool/manga_alive.json（能用的）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('扫漫画源：搜索 → 目录 → 图片', () async {
    final File input = File('tool/manga_comic_sources.json');
    final List<dynamic> raw =
        jsonDecode(input.readAsStringSync()) as List<dynamic>;
    final List<BookSource> sources = <BookSource>[
      for (final dynamic e in raw)
        if (e is Map<String, dynamic>) BookSource.fromJson(e),
    ].where((BookSource s) => s.url.trim().isNotEmpty).toList();

    final List<String> log = <String>[];
    final List<Map<String, dynamic>> alive = <Map<String, dynamic>>[];
    final Stopwatch total = Stopwatch()..start();

    for (int i = 0; i < sources.length; i++) {
      final BookSource s = sources[i];
      final Stopwatch sw = Stopwatch()..start();
      String hits = '-';
      String chapters = '-';
      String images = '-';
      String err = '';

      final SourceEngine engine = SourceEngine(
        http: HttpService(timeout: const Duration(seconds: 12)),
      );

      Future<void> probe() async {
        final List<String> keys = <String>[
          if (s.ruleSearch.checkKeyWord.trim().isNotEmpty)
            s.ruleSearch.checkKeyWord.trim(),
          '斗罗大陆',
          '火影忍者',
        ];
        List<dynamic> books = <dynamic>[];
        String used = '';
        for (final String k in keys) {
          try {
            final List<dynamic> got = await engine.search(s, k);
            if (got.isNotEmpty) {
              books = got;
              used = k;
              break;
            }
          } on Object {
            continue;
          }
        }
        hits = '${books.length}${used.isEmpty ? '' : '($used)'}';
        if (books.isEmpty) return;

        final dynamic first = books.first;
        final String bookUrl = first.bookUrl as String;
        if (bookUrl.isEmpty) return;

        try {
          final dynamic info = await engine.bookInfo(s, bookUrl,
              fallbackName: first.name as String);
          final List<dynamic> chs =
              await engine.chapters(s, info, maxPages: 1);
          chapters = chs.length.toString();
          if (chs.isEmpty) return;

          // 漫画站第一话常常是「公告」，挑中间的一话更能代表真实情况。
          final dynamic ch = chs[chs.length ~/ 2];
          final dynamic content = await engine.content(s, ch, maxPages: 1);
          final List<String> imgs =
              (content.images as List<String>).where((String u) => u.isNotEmpty).toList();
          images = imgs.length.toString();
          if (imgs.isEmpty) return;

          final List<int> head = await engine.http.imageBytes(
            imgs.first,
            headers: TextUtil.imageHeaders(
              imgs.first,
              referer: (content.referer as String?) ?? bookUrl,
            ),
          );
          if (head.length > 2000) {
            alive.add(<String, dynamic>{
              'name': s.name,
              'url': s.url,
              'rule': s.raw,
              'hits': books.length,
              'chapters': chs.length,
              'images': imgs.length,
              'firstImageBytes': head.length,
            });
          } else {
            images = '$images(bytes=${head.length})';
          }
        } on Object catch (e) {
          final String msg = e.toString().split('\n').first;
          err = msg.substring(0, msg.length.clamp(0, 90));
        }
      }

      try {
        await probe().timeout(const Duration(seconds: 75));
      } on Object catch (e) {
        err = '超时/异常 ${e.toString().split('\n').first}';
      }

      final String line = '${(i + 1).toString().padLeft(2)}. '
          '${s.name.padRight(16)} hits=$hits chapters=$chapters images=$images '
          '${sw.elapsedMilliseconds}ms ${err.isEmpty ? '' : 'ERR=$err'} ${s.url}';
      // ignore: avoid_print
      print(line);
      log.add(line);
      File('tool/manga_scan_report.txt').writeAsStringSync(
        '${log.join('\n')}\n',
        flush: true,
      );
    }

    File('tool/manga_alive.json').writeAsStringSync(
      const JsonEncoder.withIndent(' ').convert(alive),
    );
    log.add('');
    log.add('可用 ${alive.length}/${sources.length}，用时 ${total.elapsed.inSeconds}s');
    File('tool/manga_scan_report.txt')
        .writeAsStringSync('${log.join('\n')}\n', flush: true);

    expect(true, isTrue);
  }, timeout: const Timeout(Duration(minutes: 45)));
}
