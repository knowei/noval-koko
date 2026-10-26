import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noval/src/model/book_info.dart';
import 'package:noval/src/model/book_source.dart';
import 'package:noval/src/model/search_book.dart';
import 'package:noval/src/source/source_engine.dart';

/// 真实网络端到端验证：用 `sample_sources/standardebooks.json`
/// 走一遍 搜索 → 书目 → 目录 → 正文，断言每一环节都有真实数据。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('真实书源：搜索 → 书目 → 目录 → 正文', (WidgetTester tester) async {
    final String raw =
        File('sample_sources/standardebooks.json').readAsStringSync();
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    final BookSource source =
        BookSource.fromJson(list.first as Map<String, dynamic>);

    // ignore: avoid_print
    print('书源：${source.name} | ${source.url} | 可搜索=${source.canSearch}');

    final SourceEngine engine = SourceEngine();

    // 1) 搜索
    final List<SearchBook> found = await engine.search(source, 'pride');
    // ignore: avoid_print
    print('搜索命中 ${found.length} 条');
    for (final SearchBook b in found.take(3)) {
      // ignore: avoid_print
      print('  《${b.name}》 ${b.author} | ${b.bookUrl} | 封面=${b.cover}');
    }
    expect(found, isNotEmpty, reason: '搜索结果为空');

    final SearchBook first = found.first;

    // 2) 书目
    final BookInfo info = await engine.bookInfo(source, first.bookUrl);
    // ignore: avoid_print
    print('书目：《${info.name}》 作者=${info.author} 目录页=${info.tocUrl}');
    // ignore: avoid_print
    print('  简介=${info.intro.length > 80 ? info.intro.substring(0, 80) : info.intro}');
    // ignore: avoid_print
    print('  封面=${info.cover}');
    expect(info.name, isNotEmpty, reason: '书目名称为空');
    expect(info.tocUrl, contains('/text'), reason: '目录页地址不正确');

    // 3) 目录
    final List<BookChapter> chapters = await engine.chapters(source, info);
    // ignore: avoid_print
    print('目录 ${chapters.length} 章');
    for (final BookChapter c in chapters.take(4)) {
      // ignore: avoid_print
      print('  [${c.index}] ${c.title} -> ${c.url}');
    }
    expect(chapters.length, greaterThan(5), reason: '目录章节数过少');

    // 4) 正文（挑章节：跳过版权/扉页类页面，取第一个字数够的正文页）
    const List<String> boilerplate = <String>[
      'titlepage', 'imprint', 'dedication', 'preface', 'contents',
      'colophon', 'copyright', 'licence', 'license', 'endnotes',
      'uncopyright', 'halftitle', 'frontispiece', 'loi', 'translator',
    ];
    BookContent? content;
    BookChapter? target;
    for (final BookChapter c in chapters) {
      final String u = c.url.toLowerCase();
      if (boilerplate.any(u.contains)) continue;
      try {
        final BookContent got = await engine.content(source, c);
        // ignore: avoid_print
        print('  试读 [${c.index}] ${c.title} -> ${got.text.length} 字');
        if (got.text.length > 500) {
          content = got;
          target = c;
          break;
        }
      } catch (e) {
        // ignore: avoid_print
        print('  试读 [${c.index}] ${c.title} -> ERR $e');
      }
    }
    expect(content, isNotNull, reason: '没有取到任何正文页');
    final String text = content!.text;
    // ignore: avoid_print
    print('正文「${target!.title}」长度=${text.length} 图=${content.images.length}');
    // ignore: avoid_print
    print('  开头=${text.substring(0, text.length < 100 ? text.length : 100)}');
    expect(text.length, greaterThan(500), reason: '正文过短');
  });
}
