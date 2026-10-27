// 笔趣阁 m.bigee.cc 真实源回归：搜索(JSON) → 详情 → 目录 → 正文
// 跑法：flutter test integration_test/bigee_test.dart -d windows
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
    jsonDecode(File('sample_sources/bigee.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  SourceEngine newEngine() =>
      SourceEngine(http: HttpService(timeout: const Duration(seconds: 25)));

  test('笔趣阁：搜索（JSON 接口）', () async {
    final SourceEngine engine = newEngine();
    final List<SearchBook> hits = await engine.search(source, '剑来');
    final StringBuffer sb = StringBuffer()..writeln('搜索「剑来」共 ${hits.length} 条');
    for (final SearchBook b in hits.take(5)) {
      sb.writeln('  ${b.name} | ${b.author} | ${b.cover} | ${b.bookUrl}');
    }
    File('tool/bigee_result.txt').writeAsStringSync(sb.toString());
    expect(hits, isNotEmpty, reason: 'JSON 搜索接口应返回结果');
    expect(hits.first.name, contains('剑来'));
    expect(hits.first.bookUrl, contains('/book/'));
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('笔趣阁：详情 → 目录 → 正文', () async {
    final SourceEngine engine = newEngine();
    final List<SearchBook> hits = await engine.search(source, '剑来');
    expect(hits, isNotEmpty);

    final SearchBook hit =
        hits.firstWhere((SearchBook b) => b.name == '剑来', orElse: () => hits.first);
    final BookInfo info = await engine.bookInfo(source, hit.bookUrl,
        fallbackName: hit.name, fallbackAuthor: hit.author);
    final List<BookChapter> chapters = await engine.chapters(source, info);

    final StringBuffer log = StringBuffer()
      ..writeln('《${info.name}》 作者=${info.author} 分类=${info.kind}')
      ..writeln('封面=${info.cover}')
      ..writeln('最新章节=${info.lastChapter}')
      ..writeln('目录=${info.tocUrl} 章节数=${chapters.length}');
    expect(info.name, contains('剑来'));
    expect(chapters.length, greaterThanOrEqualTo(1000), reason: '《剑来》目录应有一千多章');

    final BookContent content = await engine.content(source, chapters.first);
    final String plain = content.text.replaceAll(RegExp(r'<[^>]+>'), '').trim();
    log
      ..writeln('首章「${chapters.first.title}」正文 ${plain.length} 字')
      ..writeln('URL=${chapters.first.url}')
      ..writeln('预览：${plain.substring(0, plain.length > 160 ? 160 : plain.length)}');
    File('tool/bigee_result.txt').writeAsStringSync(log.toString());

    expect(plain.length, greaterThan(500), reason: '章节页应能拿到正文（?all=1 绕过门禁）');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
