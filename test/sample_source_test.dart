import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noval/src/db/source_repo.dart';
import 'package:noval/src/model/book_info.dart';
import 'package:noval/src/model/book_source.dart';
import 'package:noval/src/model/search_book.dart';
import 'package:noval/src/source/source_engine.dart';
import 'package:noval/src/ui/reader/read_theme.dart';

import '../tool/mock_site_server.dart';

/// 用仓库里自带的 docs/mock_source.json + tool/mock_site.dart 做端到端验证。
/// 保证「示例书源文件」本身没写错，也保证导入 → 搜索 → 目录 → 正文全线通。
void main() {
  late MockSite site;

  setUpAll(() async {
    site = await MockSite.start(port: 8787);
  });

  tearDownAll(() async {
    await site.close();
  });

  List<BookSource> loadSources() {
    final String text =
        File('docs/mock_source.json').readAsStringSync();
    final List<BookSource> list = SourceRepo.parseSources(text);
    expect(list.length, 2);
    return list;
  }

  test('示例文件：小说书源全链路', () async {
    final BookSource source = loadSources().firstWhere((BookSource s) => s.isText);
    final SourceEngine engine = SourceEngine();
    try {
      final List<SearchBook> books = await engine.search(source, '仙侠');
      expect(books.length, 3);
      expect(books.first.name, '仙侠 之书 1');
      expect(books.first.bookUrl, '${site.url}/book/1');

      final BookInfo info = await engine.bookInfo(source, books.first.bookUrl);
      expect(info.name, '测试之书 1');
      expect(info.tocUrl, '${site.url}/toc/1');

      final List<BookChapter> chapters = await engine.chapters(source, info);
      expect(chapters.length, 12);
      expect(chapters.first.title, '第 1 章 标题文字');

      final BookContent content = await engine.content(source, chapters.first);
      final String plain = htmlToPlainText(content.text);
      expect(plain, contains('第 1 章第 1 段正文'));
      expect(plain, contains('第 1 章第 14 段正文'));
    } finally {
      engine.dispose();
    }
  });

  test('示例文件：漫画书源全链路', () async {
    final BookSource source =
        loadSources().firstWhere((BookSource s) => s.isComic);
    final SourceEngine engine = SourceEngine();
    try {
      final List<SearchBook> books = await engine.search(source, '热血');
      expect(books.length, 3);
      expect(books.first.bookUrl, '${site.url}/comic/1');

      final BookInfo info = await engine.bookInfo(source, books.first.bookUrl);
      expect(info.name, '漫画测试 1');
      expect(info.tocUrl, '${site.url}/comic-toc/1');

      final List<BookChapter> chapters = await engine.chapters(source, info);
      expect(chapters.length, 2);

      final BookContent content = await engine.content(source, chapters.first);
      expect(content.images.length, 5);
      expect(content.images.first, '${site.url}/i/1-1-1.png');
    } finally {
      engine.dispose();
    }
  });
}
