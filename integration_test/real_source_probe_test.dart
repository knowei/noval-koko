// 真实书源体检：拿现成的 Legado 书源 JSON，逐个源跑「搜索 → 详情 → 目录 → 正文」，
// 打印兼容性报告，用于发现我们规则引擎的缺口。
//
// 用法（需要桌面/真机，因为用到 QuickJS）：
//   $env:PROBE_SOURCE_FILE='sample_sources/yijie_bookSource.json'
//   $env:PROBE_KEYWORD='剑来'
//   $env:PROBE_LIMIT='30'
//   flutter test integration_test/real_source_probe_test.dart -d windows
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noval/src/db/source_repo.dart';
import 'package:noval/src/model/book_info.dart';
import 'package:noval/src/model/book_source.dart';
import 'package:noval/src/model/search_book.dart';
import 'package:noval/src/source/source_engine.dart';
import 'package:noval/src/ui/reader/read_theme.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('真实书源体检', (WidgetTester tester) async {
    final String file = Platform.environment['PROBE_SOURCE_FILE'] ?? '';
    final String keyword = Platform.environment['PROBE_KEYWORD'] ?? '剑来';
    final int limit =
        int.tryParse(Platform.environment['PROBE_LIMIT'] ?? '') ?? 999;
    if (file.isEmpty) {
      // ignore: avoid_print
      print('未指定 PROBE_SOURCE_FILE，跳过');
      return;
    }
    final String text = File(file).readAsStringSync();
    final List<BookSource> all = SourceRepo.parseSources(text);
    final List<BookSource> sources = all.take(limit).toList();
    // ignore: avoid_print
    print('解析到 ${all.length} 个书源，本次体检 ${sources.length} 个，关键词「$keyword」');

    for (final BookSource src in sources) {
      final StringBuffer log = StringBuffer();
      log.write('${src.name} | ${src.url}');
      final SourceEngine engine = SourceEngine();
      final Stopwatch sw = Stopwatch()..start();
      try {
        final List<SearchBook> books = await engine.search(src, keyword);
        if (books.isEmpty) {
          log.write(' | 搜索 0 条');
          // ignore: avoid_print
          print(log);
          continue;
        }
        log.write(' | 搜索 ${books.length} 条: ${books.first.name}');

        final BookInfo info = await engine.bookInfo(src, books.first.bookUrl);
        log.write(' | 详情: ${info.name.isEmpty ? "(空)" : info.name}');

        final List<BookChapter> chapters = await engine.chapters(src, info);
        log.write(' | 目录 ${chapters.length} 章');

        if (chapters.isNotEmpty) {
          final BookContent content = await engine.content(src, chapters.first);
          final String plain = htmlToPlainText(content.text).trim();
          final String head =
              plain.length > 40 ? '${plain.substring(0, 40)}…' : plain;
          log.write(' | 正文 ${plain.length} 字: ${head.replaceAll("\n", " ")}');
          if (content.images.isNotEmpty) {
            log.write(' | 图片 ${content.images.length} 张');
          }
        }
        log.write(' | ${sw.elapsedMilliseconds}ms');
        // ignore: avoid_print
        print('OK  $log');
      } catch (e) {
        log.write(' | ${e.toString().split("\n").first}');
        // ignore: avoid_print
        print('ERR $log');
      } finally {
        engine.dispose();
      }
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}
