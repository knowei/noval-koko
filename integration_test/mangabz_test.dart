// MangaBZ（www.mangabz.com）真实源回归：搜索 → 详情 → 目录 → 正文图片
// 图片地址被 Dean Edwards packer 压缩，走引擎预置的 __unpack 解开后 eval 取数组。
// 跑法：flutter test integration_test/mangabz_test.dart -d windows
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noval/src/core/text_util.dart';
import 'package:noval/src/model/book_info.dart';
import 'package:noval/src/model/book_source.dart';
import 'package:noval/src/model/search_book.dart';
import 'package:noval/src/net/http_service.dart';
import 'package:noval/src/source/source_engine.dart';

void main() {
  final BookSource source = BookSource.fromJson(
    jsonDecode(File('sample_sources/mangabz.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  SourceEngine newEngine() =>
      SourceEngine(http: HttpService(timeout: const Duration(seconds: 30)));

  test('MangaBZ：搜索 → 详情 → 目录 → 正文图片', () async {
    final SourceEngine engine = newEngine();
    final StringBuffer log = StringBuffer();

    final List<SearchBook> hits = await engine.search(source, '斗罗大陆');
    log.writeln('搜索「斗罗大陆」共 ${hits.length} 条');
    for (final SearchBook b in hits.take(5)) {
      log.writeln('  ${b.name} | ${b.author} | ${b.bookUrl}');
    }
    expect(hits, isNotEmpty, reason: 'MangaBZ 搜索应有结果');

    final SearchBook first = hits.first;
    final BookInfo info = await engine.bookInfo(source, first.bookUrl);
    log.writeln('详情：${info.name} | 作者 ${info.author} | 封面 ${info.cover}');
    expect(info.name, isNotEmpty);

    final List<BookChapter> chapters = await engine.chapters(source, info);
    log.writeln('目录 ${chapters.length} 章，首章 ${chapters.first.title}');
    for (final BookChapter c in chapters.take(3)) {
      log.writeln('  ${c.index} ${c.title} ${c.url}');
    }
    expect(chapters, isNotEmpty);

    final BookChapter chapter = chapters[chapters.length - 1];
    final BookContent content = await engine.content(source, chapter);
    log.writeln('正文：${chapter.title} → ${content.images.length} 张图');
    for (final String u in content.images.take(3)) {
      log.writeln('  $u');
    }
    expect(content.images, isNotEmpty, reason: '漫画章节应有图片');

    final HttpService http = HttpService(timeout: const Duration(seconds: 30));
    final List<int> bytes = await http.imageBytes(
      content.images.first,
      headers: TextUtil.imageHeaders(
        content.images.first,
        referer: content.referer,
      ),
    );
    log.writeln('referer=${content.referer} 首图字节数 ${bytes.length}');
    expect(bytes.length, greaterThan(3000), reason: '图片应当真能下载');

    File('tool/mangabz_result.txt').writeAsStringSync(log.toString());
  }, timeout: const Timeout(Duration(minutes: 8)));
}

