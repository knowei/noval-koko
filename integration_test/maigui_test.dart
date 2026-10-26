// 麦归文学（maiguiread.com）真实源回归：搜索 → 详情 → 目录 → 正文
// 跑法：flutter test integration_test/maigui_test.dart -d windows
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
    jsonDecode(File('sample_sources/maigui.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  SourceEngine newEngine() =>
      SourceEngine(http: HttpService(timeout: const Duration(seconds: 40)));

  test('麦归文学：搜索「解忧杂货店」', () async {
    final SourceEngine engine = newEngine();
    final List<SearchBook> hits = await engine.search(source, '解忧杂货店');
    final StringBuffer sb = StringBuffer()..writeln('搜索「解忧杂货店」共 ${hits.length} 条');
    for (final SearchBook b in hits.take(5)) {
      sb.writeln('  ${b.name} | ${b.author} | ${b.cover}');
      sb.writeln('    ${b.bookUrl}');
    }
    File('tool/maigui_result.txt').writeAsStringSync(sb.toString());
    expect(hits, isNotEmpty, reason: '这站有《解忧杂货店》');
    expect(hits.first.name, contains('解忧'));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('麦归文学：详情 → 目录 → 正文', () async {
    final SourceEngine engine = newEngine();
    final List<SearchBook> hits = await engine.search(source, '解忧杂货店');
    expect(hits, isNotEmpty);

    final SearchBook hit = hits.first;
    final BookInfo info = await engine.bookInfo(
      source,
      hit.bookUrl,
      fallbackName: hit.name,
      fallbackAuthor: hit.author,
      fallbackCover: hit.cover,
    );
    final List<BookChapter> chapters = await engine.chapters(source, info);

    final StringBuffer log = StringBuffer()
      ..writeln('《${info.name}》 作者=${info.author}')
      ..writeln('封面=${info.cover}')
      ..writeln('分类=${info.kind}')
      ..writeln('简介=${info.intro.length > 60 ? info.intro.substring(0, 60) : info.intro}')
      ..writeln('目录接口=${info.tocUrl}')
      ..writeln('章节数=${chapters.length}');
    for (final BookChapter c in chapters.take(6)) {
      log.writeln('  ${c.index + 1}. ${c.title} -> ${c.url}');
    }

    expect(info.name, isNotEmpty);
    expect(info.author, isNotEmpty);
    expect(chapters.length, greaterThanOrEqualTo(3), reason: '目录接口应返回全部章节');

    final BookContent content = await engine.content(source, chapters.first);
    final String plain = content.text.replaceAll(RegExp(r'<[^>]+>'), '');
    log
      ..writeln('第 1 章「${chapters.first.title}」正文 ${plain.length} 字')
      ..writeln('正文预览：${plain.trim().substring(0, plain.trim().length > 120 ? 120 : plain.trim().length)}');
    File('tool/maigui_result.txt').writeAsStringSync(log.toString());

    expect(plain.trim().length, greaterThan(500), reason: '正文应当成段');
  }, timeout: const Timeout(Duration(minutes: 6)));
}
