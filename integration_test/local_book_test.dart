import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noval/src/app_state.dart';
import 'package:noval/src/core/charset_util.dart';
import 'package:noval/src/db/database.dart';
import 'package:noval/src/local/local_book_store.dart';
import 'package:noval/src/model/book_info.dart';
import 'package:noval/src/model/shelf_book.dart';

/// 本地导入（TXT / EPUB）的端到端验证：
/// 真造两个文件 → 走 AppState 导入 → 上书架 → 切章 → 取正文。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final Directory dir = Directory('tool/local_test');
  final String dbPath = 'tool/local_test.db';
  final StringBuffer log = StringBuffer();

  setUpAll(() async {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
  });

  tearDownAll(() {
    File('tool/local_test_report.txt')
        .writeAsStringSync(log.toString(), encoding: utf8);
  });

  testWidgets('TXT：GBK 编码 + 章节切分', (WidgetTester tester) async {
    final StringBuffer txt = StringBuffer()
      ..writeln('这是前言部分，讲一点作者的话，长度足够当一章。')
      ..writeln()
      ..writeln('第一章 初入江湖')
      ..writeln('第一章正文。'.padRight(120, '甲'))
      ..writeln()
      ..writeln('第二章 风起')
      ..writeln('第二章正文。'.padRight(120, '乙'));
    // 故意用 GBK 存盘：国内 TXT 大量是 GBK，必须能自动识别
    final Uint8List gbk = CharsetUtil.encodeText(txt.toString(), 'gbk')!;
    final File file = File('${dir.path}/novel_gbk.txt')
      ..writeAsBytesSync(gbk);

    final AppState state = await _boot(dbPath);
    final List<LocalImportResult> results =
        await state.importLocalBooks(<String>[file.path]);
    expect(results.length, 1);
    expect(results.first.error, isNull, reason: '导入失败：${results.first.error}');

    final ShelfBook book = results.first.book;
    log.writeln('[TXT] ${book.name} | ${book.intro} | 章节=${book.totalChapters}');
    expect(book.totalChapters, 3); // 前言 + 两章
    expect(state.shelf.any((ShelfBook b) => b.bookUrl == book.bookUrl), isTrue);

    final List<BookChapter> chapters = await state.loadChapters(book);
    expect(chapters.length, 3);
    expect(chapters[1].title, contains('第一章'));
    log.writeln('[TXT] 目录：${chapters.map((BookChapter c) => c.title).join(' / ')}');

    final BookContent content = await state.loadContent(book, chapters[1]);
    expect(content.text, contains('第一章正文'));
    expect(content.text, isNot(contains('第二章')));
    log.writeln('[TXT] 第2章正文 ${content.text.length} 字');

    final BookContent last = await state.loadContent(book, chapters[2]);
    expect(last.text, contains('第二章正文'));

    state.dispose();
  });

  testWidgets('EPUB：OPF → spine → 取正文', (WidgetTester tester) async {
    final File file = File('${dir.path}/book.epub')
      ..writeAsBytesSync(_buildEpub());

    final AppState state = await _boot('tool/local_test_epub.db');
    final List<LocalImportResult> results =
        await state.importLocalBooks(<String>[file.path]);
    expect(results.first.error, isNull, reason: '导入失败：${results.first.error}');

    final ShelfBook book = results.first.book;
    log.writeln('[EPUB] ${book.name} / ${book.author} / 章节=${book.totalChapters}');
    expect(book.name, '测试之书');
    expect(book.author, '某作者');
    expect(book.totalChapters, 2);

    final List<BookChapter> chapters = await state.loadChapters(book);
    expect(chapters.length, 2);
    expect(chapters[0].title, contains('序'));

    final BookContent content = await state.loadContent(book, chapters[1]);
    expect(content.text, contains('第二章的正文'));
    expect(content.text, isNot(contains('<p>')), reason: '正文必须是纯文本');
    log.writeln('[EPUB] 第2章正文 ${content.text.length} 字：'
        '${content.text.replaceAll('\n', ' ')}');

    state.dispose();
  });
}

Future<AppState> _boot(String dbPath) async {
  final File db = File(dbPath);
  if (db.existsSync()) db.deleteSync();
  await AppDatabase.instance.init(path: dbPath);
  final AppState state = AppState();
  await state.bootstrap();
  return state;
}

/// 手工拼一个最小 EPUB（mimetype + container.xml + OPF + 两个 xhtml）。
Uint8List _buildEpub() {
  const String container = '<?xml version="1.0"?>'
      '<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
      '<rootfiles><rootfile full-path="OEBPS/content.opf" '
      'media-type="application/oebps-package+xml"/></rootfiles></container>';
  const String opf = '<?xml version="1.0"?>'
      '<package xmlns="http://www.idpf.org/2007/opf" version="3.0">'
      '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">'
      '<dc:title>测试之书</dc:title><dc:creator>某作者</dc:creator></metadata>'
      '<manifest>'
      '<item id="c1" href="ch1.xhtml" media-type="application/xhtml+xml"/>'
      '<item id="c2" href="ch2.xhtml" media-type="application/xhtml+xml"/>'
      '</manifest>'
      '<spine><itemref idref="c1"/><itemref idref="c2"/></spine>'
      '</package>';
  final String ch1 = '<?xml version="1.0" encoding="utf-8"?>'
      '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>序</title></head>'
      '<body><h1>序</h1><p>这是序章的正文，长度凑够一点，免得被当成封面页丢掉。</p>'
      '</body></html>';
  final String ch2 = '<?xml version="1.0" encoding="utf-8"?>'
      '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>第二章</title></head>'
      '<body><h2>第二章 起风了</h2><p>第二章的正文在这里。</p><p>还有第二段。</p>'
      '</body></html>';

  final Archive archive = Archive()
    ..add(ArchiveFile.string('mimetype', 'application/epub+zip'))
    ..add(ArchiveFile.string('META-INF/container.xml', container))
    ..add(ArchiveFile.string('OEBPS/content.opf', opf))
    ..add(ArchiveFile.string('OEBPS/ch1.xhtml', ch1))
    ..add(ArchiveFile.string('OEBPS/ch2.xhtml', ch2));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
