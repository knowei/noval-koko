import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noval/src/model/book_info.dart';
import 'package:noval/src/model/book_source.dart';
import 'package:noval/src/model/search_book.dart';
import 'package:noval/src/source/source_engine.dart';

/// 真实站点点二连：轻之文库（linovel.net）搜「史莱姆」，断言四段全有数据。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('轻之文库：搜「史莱姆」→ 书目 → 目录 → 正文', (WidgetTester tester) async {
    final String raw =
        File('sample_sources/linovel.json').readAsStringSync();
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    final BookSource source =
        BookSource.fromJson(list.first as Map<String, dynamic>);

    // ignore: avoid_print
    print('书源：${source.name} | ${source.url}');

    final SourceEngine engine = SourceEngine();
    final List<SearchBook> found = await engine.search(source, '史莱姆');
    // ignore: avoid_print
    print('搜索命中 ${found.length} 条');
    for (final SearchBook b in found.take(5)) {
      // ignore: avoid_print
      print('  《${b.name}》 ${b.author} | ${b.bookUrl} | ${b.intro.length > 30 ? b.intro.substring(0, 30) : b.intro}');
    }
    expect(found, isNotEmpty, reason: '轻之文库搜索无结果');

    final SearchBook first = found.first;
    expect(first.name, isNotEmpty);
    expect(first.bookUrl, startsWith('http'));

    final BookInfo info = await engine.bookInfo(source, first.bookUrl);
    // ignore: avoid_print
    print('书目：《${info.name}》 作者=${info.author} 封面=${info.cover.isNotEmpty}');
    // ignore: avoid_print
    print('  简介=${info.intro.length > 60 ? info.intro.substring(0, 60) : info.intro}');
    expect(info.name, isNotEmpty, reason: '书目名称为空');

    final List<BookChapter> chapters = await engine.chapters(source, info);
    // ignore: avoid_print
    print('目录 ${chapters.length} 章，前 3：'
        '${chapters.take(3).map((BookChapter c) => c.title).join(' / ')}');
    expect(chapters.length, greaterThan(3), reason: '目录章节数过少');

    BookContent? content;
    BookChapter? target;
    for (final BookChapter c in chapters) {
      try {
        final BookContent got = await engine.content(source, c);
        // ignore: avoid_print
        print('  试读 [${c.index}] ${c.title} -> ${got.text.length} 字');
        if (got.text.length > 300) {
          content = got;
          target = c;
          break;
        }
      } catch (e) {
        // ignore: avoid_print
        print('  试读 [${c.index}] ${c.title} -> ERR $e');
      }
    }
    expect(content, isNotNull, reason: '没有取到任何正文');
    final String text = content!.text;
    // ignore: avoid_print
    print('正文「${target!.title}」长度=${text.length}');
    // ignore: avoid_print
    print('  开头=${text.substring(0, text.length < 80 ? text.length : 80)}');
    expect(text.length, greaterThan(300), reason: '正文过短');
  });
}
