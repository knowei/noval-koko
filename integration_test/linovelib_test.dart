// 哔哩轻小说（linovelib.com）真实源回归：搜索 → 详情 → 目录 → 正文
// 跑法：flutter test integration_test/linovelib_test.dart -d windows
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noval/src/model/book_info.dart';
import 'package:noval/src/model/book_source.dart';
import 'package:noval/src/model/search_book.dart';
import 'package:noval/src/net/http_service.dart';
import 'package:noval/src/source/source_engine.dart';

void main() {
  final BookSource source = BookSource.fromJson(
    jsonDecode(File('sample_sources/linovelib.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  SourceEngine newEngine() =>
      SourceEngine(http: HttpService(timeout: const Duration(seconds: 25)));

  test('哔哩轻小说：搜索', () async {
    final SourceEngine engine = newEngine();
    final List<SearchBook> hits = await engine.search(source, '史莱姆');
    final StringBuffer sb = StringBuffer('搜索「史莱姆」共 ${hits.length} 条\n');
    for (final SearchBook b in hits.take(5)) {
      sb.writeln('${b.name} | ${b.author} | ${b.bookUrl}');
    }
    File('tool/linovelib_result.txt').writeAsStringSync(sb.toString());
    expect(hits.length, greaterThanOrEqualTo(3), reason: '搜索结果应当有若干条');
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('哔哩轻小说：详情 → 目录 → 正文（自动跳过空章节）', () async {
    final SourceEngine engine = newEngine();
    final List<SearchBook> hits = await engine.search(source, '史莱姆');
    expect(hits, isNotEmpty);

    final StringBuffer log = StringBuffer();
    String picked = '';
    for (final SearchBook hit in hits) {
      BookInfo info;
      List<BookChapter> chapters;
      try {
        info = await engine.bookInfo(
          source,
          hit.bookUrl,
          fallbackName: hit.name,
          fallbackAuthor: hit.author,
        );
        chapters = await engine.chapters(source, info);
      } catch (e) {
        log.writeln('《${hit.name}》详情/目录失败：$e');
        continue;
      }
      log.writeln('《${info.name}》作者=${info.author} '
          '目录=${info.tocUrl} 章节数=${chapters.length}');
      if (chapters.length < 5) continue;

      // 空章节（站点提示「未通过审核」）跳过，从中间开始试几章
      final int from = chapters.length * 2 ~/ 3;
      for (int i = from; i < chapters.length && i < from + 10; i++) {
        BookContent content;
        try {
          content = await engine.content(source, chapters[i]);
        } catch (e) {
          log.writeln('  第 ${i + 1} 章请求失败：$e');
          continue;
        }
        final String plain = content.text.replaceAll(RegExp(r'<[^>]+>'), '');
        log.writeln('  第 ${i + 1} 章「${chapters[i].title}」'
            '正文 ${plain.length} 字，图片 ${content.images.length} 张');
        if (plain.trim().length > 300) {
          log.writeln('正文预览：${plain.trim().substring(0, 200)}');
          picked = info.name;
          File('tool/linovelib_result.txt').writeAsStringSync(log.toString());
          expect(plain.trim().length, greaterThan(300));
          return;
        }
      }
    }
    File('tool/linovelib_result.txt').writeAsStringSync(log.toString());
    fail('搜索结果里没有取到正文（picked=$picked）');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
