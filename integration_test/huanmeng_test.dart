// 幻梦轻小说（huanmengacg.com）真实源回归：搜索 → 详情 → 目录 → 正文
// 跑法：flutter test integration_test/huanmeng_test.dart -d windows
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
    jsonDecode(File('sample_sources/huanmeng.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  SourceEngine newEngine() =>
      SourceEngine(http: HttpService(timeout: const Duration(seconds: 25)));

  test('幻梦轻小说：搜索', () async {
    final SourceEngine engine = newEngine();
    final StringBuffer sb = StringBuffer();
    for (final String kw in <String>['妹妹人生', '史莱姆']) {
      final List<SearchBook> hits = await engine.search(source, kw);
      sb.writeln('搜索「$kw」共 ${hits.length} 条');
      for (final SearchBook b in hits.take(3)) {
        sb.writeln('  ${b.name} | ${b.author} | ${b.cover} | ${b.bookUrl}');
      }
    }
    File('tool/huanmeng_result.txt').writeAsStringSync(sb.toString());
    expect(sb.toString(), contains('妹妹人生'));
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('幻梦轻小说：详情 → 目录 → 正文', () async {
    final SourceEngine engine = newEngine();
    final List<SearchBook> hits = await engine.search(source, '妹妹人生');
    expect(hits, isNotEmpty, reason: '应能搜到《妹妹人生》');

    final SearchBook hit = hits.firstWhere(
      (SearchBook b) => b.name.contains('妹妹人生'),
      orElse: () => hits.first,
    );
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
      ..writeln('分类=${info.kind} 状态/最新章节=${info.lastChapter}')
      ..writeln('简介=${info.intro.length > 60 ? info.intro.substring(0, 60) : info.intro}')
      ..writeln('目录=${info.tocUrl} 章节数=${chapters.length}');
    expect(info.name, isNotEmpty);
    expect(chapters.length, greaterThanOrEqualTo(10), reason: '书本页应有完整目录');

    // 第 1 章是「序」，比较短；优先找一章够长的
    String plain = '';
    String title = '';
    BookContent content = await engine.content(source, chapters.first);
    for (int i = 0; i < chapters.length && i < 6; i++) {
      final BookContent c = i == 0 ? content : await engine.content(source, chapters[i]);
      final String p = c.text.replaceAll(RegExp(r'<[^>]+>'), '').trim();
      log.writeln('第 ${i + 1} 章「${chapters[i].title}」正文 ${p.length} 字');
      if (p.length > 400) {
        content = c;
        plain = p;
        title = chapters[i].title;
        break;
      }
    }
    log.writeln('选中章节：$title');
    log.writeln('正文预览：${plain.substring(0, plain.length > 160 ? 160 : plain.length)}');
    File('tool/huanmeng_result.txt').writeAsStringSync(log.toString());

    expect(plain.length, greaterThan(400), reason: '正文应当成段（已按 order 排序、剔除干扰段）');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
