import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noval/src/model/book_info.dart';
import 'package:noval/src/model/book_source.dart';
import 'package:noval/src/model/search_book.dart';
import 'package:noval/src/source/source_engine.dart';

/// 日本轻小说源：カクヨム（kakuyomu.jp）。搜「スライム」→ 书目 → 目录 → 日文正文。
///
/// 只做验证，不进 app（用户要求「先别写到 app，用代码跑通后给我看」）。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final StringBuffer log = StringBuffer();
  void say(Object? s) {
    log.writeln(s);
    // ignore: avoid_print
    print(s);
  }

  testWidgets('カクヨム：搜「スライム」→ 书目 → 目录 → 正文', (WidgetTester tester) async {
    final String raw = File('sample_sources/kakuyomu.json').readAsStringSync();
    final dynamic decoded = jsonDecode(raw);
    final Map<String, dynamic> json = decoded is List<dynamic>
        ? decoded.first as Map<String, dynamic>
        : decoded as Map<String, dynamic>;
    final BookSource source = BookSource.fromJson(json);

    say('书源：${source.name} | ${source.url}');

    final SourceEngine engine = SourceEngine();
    final List<SearchBook> found = await engine.search(source, 'スライム');
    say('搜索命中 ${found.length} 条');
    for (final SearchBook b in found.take(6)) {
      say('  《${b.name}》 作者=${b.author} | ${b.bookUrl}');
    }
    expect(found, isNotEmpty, reason: 'カクヨム 搜索无结果');

    final SearchBook first = found.first;
    expect(first.name, isNotEmpty);
    expect(first.bookUrl, startsWith('https://kakuyomu.jp/works/'));

    final BookInfo info = await engine.bookInfo(source, first.bookUrl);
    say('书目：《${info.name}》');
    say('  作者=${info.author}');
    say('  简介=${info.intro.replaceAll('\n', ' ')}');
    expect(info.name, isNotEmpty, reason: '书目名称为空');

    final List<BookChapter> chapters = await engine.chapters(source, info);
    say('目录 ${chapters.length} 章');
    for (final BookChapter c in chapters.take(5)) {
      say('  [${c.index}] ${c.title} -> ${c.url}');
    }
    expect(chapters.length, greaterThan(3), reason: '目录章节数过少');

    BookContent? content;
    BookChapter? target;
    for (final BookChapter c in chapters.take(3)) {
      try {
        final BookContent got = await engine.content(source, c);
        say('  试读 [${c.index}] ${c.title} -> ${got.text.length} 字');
        if (got.text.length > 200) {
          content = got;
          target = c;
          break;
        }
      } catch (e) {
        say('  试读 [${c.index}] ${c.title} -> ERR $e');
      }
    }
    expect(content, isNotNull, reason: '没有取到任何正文');

    final String text = content!.text;
    say('正文《${target!.title}》长度=${text.length}');
    final List<String> lines = text
        .split('\n')
        .where((String l) => l.trim().isNotEmpty)
        .toList();
    for (final String l in lines.take(12)) {
      say('  | $l');
    }
    expect(text.length, greaterThan(200), reason: '正文过短');

    File('tool/kakuyomu_result.txt').writeAsStringSync(log.toString());
  });

  testWidgets('カクヨム：长连载作品目录完整（437 话）', (WidgetTester tester) async {
    final dynamic decoded =
        jsonDecode(File('sample_sources/kakuyomu.json').readAsStringSync());
    final Map<String, dynamic> json = decoded is List<dynamic>
        ? decoded.first as Map<String, dynamic>
        : decoded as Map<String, dynamic>;
    final BookSource source = BookSource.fromJson(json);
    final SourceEngine engine = SourceEngine();

    final List<SearchBook> found = await engine.search(source, '生活魔法使い');
    expect(found, isNotEmpty, reason: '搜不到目标作品');

    final SearchBook hit = found.firstWhere(
      (SearchBook b) => b.bookUrl.contains('16816700426194102610'),
      orElse: () => found.first,
    );
    say('\n[长作品] 《${hit.name}》 ${hit.bookUrl}');

    final BookInfo info = await engine.bookInfo(source, hit.bookUrl);
    final List<BookChapter> chapters = await engine.chapters(source, info);
    say('[长作品] 目录 ${chapters.length} 章；首=${chapters.first.title}；末=${chapters.last.title}');
    expect(chapters.length, greaterThan(100), reason: '长作品目录解析不完整');

    final BookContent got = await engine.content(source, chapters.last);
    say('[长作品] 末章《${chapters.last.title}》正文 ${got.text.length} 字');
    expect(got.text.length, greaterThan(200));

    File('tool/kakuyomu_result.txt')
        .writeAsStringSync('$log', mode: FileMode.append);
  });
}
