// 可阅文学网（kepub.net）真实源回归：搜索 → 详情 → 目录 → 正文
// 跑法：flutter test integration_test/kepub_test.dart -d windows
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
    jsonDecode(File('sample_sources/kepub.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  SourceEngine newEngine() =>
      SourceEngine(http: HttpService(timeout: const Duration(seconds: 25)));

  test('可阅文学网：搜索中文关键字', () async {
    final SourceEngine engine = newEngine();
    final StringBuffer sb = StringBuffer();
    int total = 0;
    for (final String kw in <String>['山雨', '骆驼祥子', '红楼梦']) {
      final List<SearchBook> hits = await engine.search(source, kw);
      total += hits.length;
      sb.writeln('搜索「$kw」共 ${hits.length} 条');
      for (final SearchBook b in hits.take(3)) {
        sb.writeln('  ${b.name} | ${b.author} | ${b.cover} | ${b.bookUrl}');
      }
    }
    File('tool/kepub_result.txt').writeAsStringSync(sb.toString());
    expect(total, greaterThanOrEqualTo(3), reason: '三个关键字应能搜到书');
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('可阅文学网：详情 → 目录 → 正文', () async {
    final SourceEngine engine = newEngine();
    final List<SearchBook> hits = await engine.search(source, '山雨');
    expect(hits, isNotEmpty);

    final SearchBook hit = hits.first;
    final BookInfo info = await engine.bookInfo(
      source,
      hit.bookUrl,
      fallbackName: hit.name,
      fallbackAuthor: hit.author,
    );
    final List<BookChapter> chapters = await engine.chapters(source, info);

    final StringBuffer log = StringBuffer()
      ..writeln('《${info.name}》 作者=${info.author}')
      ..writeln('封面=${info.cover}')
      ..writeln('分类=${info.kind} 最新章节=${info.lastChapter}')
      ..writeln('简介=${info.intro.length > 60 ? info.intro.substring(0, 60) : info.intro}')
      ..writeln('目录=${info.tocUrl} 章节数=${chapters.length}');
    expect(info.name, isNotEmpty);
    expect(chapters.length, greaterThanOrEqualTo(5), reason: '书页里有完整目录');

    // 第 1 章一般是整章公开的（后面的章节是付费试读，只有一小段）
    BookContent content = await engine.content(source, chapters.first);
    String plain = content.text.replaceAll(RegExp(r'<[^>]+>'), '');
    log.writeln('第 1 章「${chapters.first.title}」正文 ${plain.length} 字');
    log.writeln('正文预览：${plain.trim().substring(0, plain.trim().length > 120 ? 120 : plain.trim().length)}');

    if (plain.trim().length < 300) {
      // 退一步：往后找一章够长的
      for (int i = 1; i < chapters.length && i < 8; i++) {
        final BookContent c = await engine.content(source, chapters[i]);
        final String p = c.text.replaceAll(RegExp(r'<[^>]+>'), '');
        log.writeln('第 ${i + 1} 章「${chapters[i].title}」正文 ${p.length} 字');
        if (p.trim().length > 300) {
          content = c;
          plain = p;
          break;
        }
      }
    }

    log.writeln('下一章：${content.nextUrl}');
    File('tool/kepub_result.txt').writeAsStringSync(log.toString());

    expect(plain.trim().length, greaterThan(300), reason: '正文应当成段');
    expect(chapters.length, greaterThan(5), reason: '目录应当完整');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
