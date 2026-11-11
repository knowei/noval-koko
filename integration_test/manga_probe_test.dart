import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noval/src/core/text_util.dart';
import 'package:noval/src/model/book_info.dart';
import 'package:noval/src/model/book_source.dart';
import 'package:noval/src/model/search_book.dart';
import 'package:noval/src/source/source_engine.dart';

/// 探针：给定书源 JSON + 关键词，跑 搜索 → 详情 → 目录（只取目录，不读正文）。
///
/// 运行：
///   $env:NOVAL_PROXY='127.0.0.1:7897'
///   flutter test integration_test/manga_probe_test.dart -d windows
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<List<String>> cases = <List<String>>[
    <String>['sample_sources/baozimh.json', '斗破苍穹'],
    <String>['sample_sources/mangabz.json', '斗破蒼穹'],
  ];

  test('漫画源目录探针', () async {
    final StringBuffer out = StringBuffer();
    final SourceEngine engine = SourceEngine();
    for (final List<String> c in cases) {
      final String file = c[0];
      final String key = c[1];
      out.writeln('\n=== $file  keyword=$key');
      final BookSource source =
          BookSource.fromJson(jsonDecode(File(file).readAsStringSync()) as Map<String, dynamic>);
      try {
        final List<SearchBook> hits = await engine.search(source, key);
        out.writeln('  search hits=${hits.length}');
        if (hits.isEmpty) continue;
        final SearchBook first = hits.first;
        out.writeln('  first: ${first.name} / ${first.author} / ${first.bookUrl}');
        final BookInfo info = await engine.bookInfo(source, first.bookUrl);
        out.writeln('  info: ${info.name} | last=${info.lastChapter} update=${info.updateTime} | intro=${info.intro.length}字');
        final List<BookChapter> chapters = await engine.chapters(source, info);
        out.writeln('  chapters=${chapters.length}');
        if (chapters.isNotEmpty) {
          out.writeln('    first: ${chapters.first.title} -> ${chapters.first.url}');
          out.writeln('    last : ${chapters.last.title} -> ${chapters.last.url}');
          final BookChapter target = chapters.last;
          final BookContent content = await engine.content(source, target);
          int bytes = 0;
          String firstUrl = '-';
          if (content.images.isNotEmpty) {
            firstUrl = content.images.first;
            try {
              final List<int> b = await engine.http.imageBytes(
                firstUrl,
                headers: TextUtil.imageHeaders(firstUrl, referer: content.referer),
              );
              bytes = b.length;
            } catch (e) {
              bytes = -1;
            }
          }
          out.writeln('    content: images=${content.images.length} text=${content.text.length}字 '
              'referer=${content.referer} 首图=$firstUrl bytes=$bytes');
        }
      } catch (e) {
        out.writeln('  ERR: $e');
      }
    }
    // ignore: avoid_print
    print(out.toString());
    try {
      File('${Directory.systemTemp.path}/manga_probe_report.txt')
          .writeAsStringSync(out.toString());
    } catch (_) {}
  }, timeout: const Timeout(Duration(minutes: 6)));
}
