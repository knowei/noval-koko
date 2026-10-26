// 包子系镜像源回归：bzmh.org / godamh.com（与 baozimh.org 同构）
// 跑法：flutter test integration_test/mh_mirrors_test.dart -d windows
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noval/src/model/book_info.dart';
import 'package:noval/src/model/book_source.dart';
import 'package:noval/src/model/search_book.dart';
import 'package:noval/src/net/http_service.dart';
import 'package:noval/src/source/source_engine.dart';

const List<String> kFiles = <String>['bzmh', 'godamh'];
const String kKeyword = '斗罗大陆';

SourceEngine newEngine() =>
    SourceEngine(http: HttpService(timeout: const Duration(seconds: 30)));

BookSource loadSource(String key) => BookSource.fromJson(
      jsonDecode(File('sample_sources/$key.json').readAsStringSync())
          as Map<String, dynamic>,
    );

void main() {
  for (final String key in kFiles) {
    test('$key：搜索 → 详情 → 目录 → 图片', () async {
      final BookSource source = loadSource(key);
      final SourceEngine engine = newEngine();
      final StringBuffer log = StringBuffer('[ $key ] ${source.url}\n');

      final List<SearchBook> hits = await engine.search(source, kKeyword);
      log.writeln('搜索「$kKeyword」共 ${hits.length} 条');
      for (final SearchBook b in hits.take(3)) {
        log.writeln('  ${b.name} | ${b.bookUrl}');
      }
      expect(hits, isNotEmpty, reason: '$key 搜索应有结果');

      final BookInfo info = await engine.bookInfo(source, hits.first.bookUrl);
      log.writeln('详情：${info.name} | 封面 ${info.cover}');
      expect(info.name, isNotEmpty);

      final List<BookChapter> chapters = await engine.chapters(source, info);
      log.writeln('目录 ${chapters.length} 章，首章 ${chapters.first.title}');
      expect(chapters.length, greaterThan(5));

      final BookChapter chapter = chapters[chapters.length ~/ 2];
      final BookContent content = await engine.content(source, chapter);
      log.writeln('正文：${chapter.title} → ${content.images.length} 张图');
      for (final String u in content.images.take(3)) {
        log.writeln('  $u');
      }
      expect(content.images.length, greaterThan(3), reason: '$key 章节应有图片');

      final List<int> bytes = await engine.http.imageBytes(content.images.first);
      log.writeln('首图字节数 ${bytes.length}');

      File('tool/mh_mirror_$key.txt').writeAsStringSync(log.toString());
      expect(bytes.length, greaterThan(5000), reason: '图片应能真实下载');
    }, timeout: const Timeout(Duration(minutes: 6)));
  }
}
