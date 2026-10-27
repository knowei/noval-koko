// MangaDex 真实源回归：搜索 → 详情 → 目录 → 图片（全走官方 API + @Home 节点）
// 跑法：flutter test integration_test/mangadex_test.dart -d windows
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
    jsonDecode(File('sample_sources/mangadex.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  SourceEngine newEngine() =>
      SourceEngine(http: HttpService(timeout: const Duration(seconds: 40)));

  test('MangaDex：搜索 → 详情 → 目录 → 图片', () async {
    final SourceEngine engine = newEngine();
    final StringBuffer log = StringBuffer();

    final List<SearchBook> hits = await engine.search(source, 'チェンソー');
    log.writeln('搜索「チェンソー」共 ${hits.length} 条');
    for (final SearchBook b in hits.take(5)) {
      log.writeln('  ${b.name} | ${b.author} | ${b.cover}');
    }
    expect(hits, isNotEmpty, reason: 'MangaDex 搜索应有结果');
    expect(hits.first.name.trim(), isNotEmpty);

    final SearchBook first = hits.first;
    final BookInfo info = await engine.bookInfo(source, first.bookUrl);
    log.writeln('详情：${info.name} | ${info.author} | 封面 ${info.cover}');
    log.writeln('  tocUrl: ${info.tocUrl}');
    log.writeln('  简介: ${info.intro.length} 字');
    expect(info.name.trim(), isNotEmpty);
    expect(info.cover, contains('uploads.mangadex.org/covers/'));

    final List<BookChapter> chapters = await engine.chapters(source, info);
    log.writeln('目录 ${chapters.length} 章，首章「${chapters.first.title}」，末章「${chapters.last.title}」');
    expect(chapters.length, greaterThan(3), reason: '目录应有章节');
    expect(chapters.first.url, contains('mangadex.org/chapter/'));

    final BookChapter chapter = chapters.first;
    final BookContent content = await engine.content(source, chapter);
    log.writeln('正文：${chapter.title} → ${content.images.length} 张图');
    for (final String u in content.images.take(3)) {
      log.writeln('  $u');
    }
    expect(content.images.length, greaterThan(3), reason: '漫画章节应有若干张图片');

    final HttpService http = HttpService(timeout: const Duration(seconds: 40));
    final List<int> bytes = await http.imageBytes(content.images.first);
    log.writeln('首图字节数 ${bytes.length}');
    expect(bytes.length, greaterThan(5000), reason: '图片应当真能下载');

    File('tool/mangadex_result.txt').writeAsStringSync(log.toString());
  }, timeout: const Timeout(Duration(minutes: 8)));
}
