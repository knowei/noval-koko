import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noval/src/model/book_info.dart';
import 'package:noval/src/model/book_source.dart';
import 'package:noval/src/model/search_book.dart';
import 'package:noval/src/net/http_service.dart';
import 'package:noval/src/source/source_engine.dart';

/// 精选书源的真实站点回归：搜索 → 详情 → 目录 → 正文。
/// 结果同时写入 tool/curated_sources_report.txt（integration test 的 stdout 拿不到）。
void main() {
  final Map<String, BookSource> byName = <String, BookSource>{};
  final StringBuffer log = StringBuffer();

  void say(String line) {
    stdout.writeln(line);
    log.writeln(line);
  }

  tearDownAll(() {
    File('tool/curated_sources_report.txt')
        .writeAsStringSync(log.toString(), encoding: utf8);
  });

  setUpAll(() {
    final dynamic decoded = jsonDecode(
        File('docs/live_sources.json').readAsStringSync(encoding: utf8));
    final List<dynamic> list =
        decoded is List<dynamic> ? decoded : <dynamic>[decoded];
    for (final dynamic item in list) {
      final BookSource s = BookSource.fromJson(item as Map<String, dynamic>);
      byName[s.name] = s;
    }
  });

  Future<void> run(String name, String key, {int minChapters = 1}) async {
    final BookSource? src = byName[name];
    expect(src, isNotNull, reason: '书源 $name 不在 docs/live_sources.json');
    final SourceEngine engine = SourceEngine(http: HttpService());

    final List<SearchBook> hits = await engine.search(src!, key);
    final List<String> top = hits
        .take(3)
        .map((SearchBook b) => '${b.name} / ${b.author}')
        .toList();
    say('[$name] 搜索「$key」→ ${hits.length} 条；前 3：$top');
    expect(hits, isNotEmpty);

    final SearchBook hit = hits.first;
    final BookInfo info = await engine.bookInfo(
      src,
      hit.bookUrl,
      fallbackName: hit.name,
      fallbackAuthor: hit.author,
      fallbackIntro: hit.intro,
      fallbackCover: hit.cover,
    );
    say('[$name] 详情：名「${info.name}」作者「${info.author}」'
        '封面=${info.cover.isEmpty ? '无' : '有'} toc=${info.tocUrl}');
    expect(info.name.trim(), isNotEmpty);

    final List<BookChapter> chapters = await engine.chapters(src, info);
    say('[$name] 目录 ${chapters.length} 章；首章「'
        '${chapters.isEmpty ? '' : chapters.first.title}」末章「'
        '${chapters.isEmpty ? '' : chapters.last.title}」');
    expect(chapters.length, greaterThanOrEqualTo(minChapters));

    // 各站目录开头常有扉页/版权页/前言（几十字），往后翻几章找真正的正文。
    String lastInfo = '';
    bool ok = false;
    for (final BookChapter ch in chapters.take(15)) {
      final BookContent content = await engine.content(src, ch);
      final String text = content.text.trim();
      if (text.length <= 200) {
        lastInfo = '「${ch.title}」只有 ${text.length} 字';
        continue;
      }
      final String head = text
          .substring(0, text.length < 80 ? text.length : 80)
          .replaceAll('\n', ' ');
      say('[$name] 正文「${ch.title}」${text.length} 字；开头：$head');
      ok = true;
      break;
    }
    expect(ok, isTrue, reason: '前 15 章都取不到 200 字以上的正文：$lastInfo');
  }

  test('SF轻小说：史莱姆', () => run('SF轻小说', '史莱姆', minChapters: 5),
      timeout: const Timeout(Duration(minutes: 5)));

  test('漢典古籍：西游记', () => run('漢典古籍', '西游记', minChapters: 5),
      timeout: const Timeout(Duration(minutes: 5)));

  test('Standard Ebooks：pride',
      () => run('Standard Ebooks', 'pride', minChapters: 30),
      timeout: const Timeout(Duration(minutes: 6)));

  test('カクヨム：スライム', () => run('カクヨム', 'スライム', minChapters: 3),
      timeout: const Timeout(Duration(minutes: 6)));
}
