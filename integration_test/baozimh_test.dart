// 包子漫画（baozimh.org）真实源回归：搜索 → 详情 → 目录 → 正文图片（图片地址加密，走官方解密器）
// 跑法：flutter test integration_test/baozimh_test.dart -d windows
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
    jsonDecode(File('sample_sources/baozimh.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  SourceEngine newEngine() =>
      SourceEngine(http: HttpService(timeout: const Duration(seconds: 30)));

  test('包子漫画：搜索 → 目录 → 正文图片', () async {
    final SourceEngine engine = newEngine();
    final StringBuffer log = StringBuffer();

    final List<SearchBook> hits = await engine.search(source, '斗罗大陆');
    log.writeln('搜索「斗罗大陆」共 ${hits.length} 条');
    for (final SearchBook b in hits.take(5)) {
      log.writeln('  ${b.name} | ${b.cover} | ${b.bookUrl}');
    }
    expect(hits, isNotEmpty, reason: '包子漫画搜索应有结果');

    final SearchBook first = hits.first;
    final BookInfo info = await engine.bookInfo(source, first.bookUrl);
    log.writeln('详情：${info.name} | 封面 ${info.cover} | 目录 ${info.tocUrl}');
    expect(info.name, isNotEmpty);

    final List<BookChapter> chapters = await engine.chapters(source, info);
    log.writeln('目录 ${chapters.length} 章，首章 ${chapters.first.title}');
    expect(chapters.length, greaterThan(10));

    // 从中间挑一章，避免首页章节常是「广告/公告」类占位
    final BookChapter chapter = chapters[chapters.length ~/ 2];
    final BookContent content = await engine.content(source, chapter);
    log.writeln('正文：${chapter.title} → ${content.images.length} 张图');
    for (final String u in content.images.take(3)) {
      log.writeln('  $u');
    }
    expect(content.images.length, greaterThan(5), reason: '漫画章节应有若干张图片');
    expect(content.images.first, startsWith('https://c-'));

    // 真下一张图，确认 URL + 图床头可用
    final HttpService http = HttpService(timeout: const Duration(seconds: 30));
    final List<int> bytes = await http.imageBytes(content.images.first);
    log.writeln('首图字节数 ${bytes.length}');
    expect(bytes.length, greaterThan(5000), reason: '图片应当真能下载');

    File('tool/baozimh_result.txt').writeAsStringSync(log.toString());
  }, timeout: const Timeout(Duration(minutes: 5)));
}
