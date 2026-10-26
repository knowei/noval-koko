import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/charset_util.dart';
import '../core/html_text.dart';
import '../model/book_info.dart';
import '../model/shelf_book.dart';

/// 一本本地书的导入结果。失败时 [error] 有值、[chapters] 为空。
class LocalImportResult {
  const LocalImportResult({
    required this.book,
    required this.chapters,
    this.error,
  });

  final ShelfBook book;
  final List<BookChapter> chapters;
  final String? error;

  bool get ok => error == null;
}

/// 本地书籍（TXT / EPUB）的导入、切章与取文。
///
/// 设计取舍：
/// - 导入时把文件**复制**进应用目录 `<appSupport>/local_books/`，书架上只记
///   `local://<文件名>`；这样原文件被挪走/删掉，书架里的书依然能读。
/// - 不把每章单独存成文件，正文每次按需重新切（10MB 的 TXT 也在百毫秒内），
///   EPUB 的解析结果在内存里缓存一份，翻章不再重新解压。
class LocalBookStore {
  LocalBookStore._();

  static final LocalBookStore instance = LocalBookStore._();

  /// 本地书在书架里的「书源」标识（不参与网络请求，只用来分流）。
  static const String sourceUrl = 'local://local';
  static const String sourceName = '本地导入';

  static bool isLocalUrl(String url) => url.startsWith('local://');

  static const String _prefix = 'local://';

  Directory? _dir;

  Future<Directory> _home() async {
    final Directory? cached = _dir;
    if (cached != null) return cached;
    final Directory base = await getApplicationSupportDirectory();
    final Directory dir = Directory(p.join(base.path, 'local_books'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _dir = dir;
    return dir;
  }

  // ------------------------------------------------------------------ import

  /// 导入若干文件。单个文件失败不会中断其它文件。
  Future<List<LocalImportResult>> importFiles(List<String> paths) async {
    final Directory dir = await _home();
    final List<LocalImportResult> out = <LocalImportResult>[];
    for (final String path in paths) {
      try {
        out.add(await _importOne(path, dir));
      } catch (e) {
        out.add(LocalImportResult(
          book: ShelfBook(
            bookUrl: '',
            name: p.basenameWithoutExtension(path),
            sourceUrl: sourceUrl,
            sourceName: sourceName,
          ),
          chapters: const <BookChapter>[],
          error: _friendly(e),
        ));
      }
    }
    return out;
  }

  Future<LocalImportResult> _importOne(String path, Directory dir) async {
    final File file = File(path);
    final Uint8List bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw const FormatException('文件是空的');
    final String title = p.basenameWithoutExtension(path);
    final String stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final bool epub =
        p.extension(path).toLowerCase() == '.epub' || _looksLikeZip(bytes);

    if (epub) {
      final String name = '$stamp.epub';
      final File copy = File(p.join(dir.path, name));
      await copy.writeAsBytes(bytes, flush: true);
      final _Epub book = await _loadEpub(copy);
      final List<BookChapter> chapters = book.toChapters();
      if (chapters.isEmpty) throw const FormatException('EPUB 里没找到章节');
      return LocalImportResult(
        book: ShelfBook(
          bookUrl: '$_prefix$name',
          name: book.title.isEmpty ? title : book.title,
          author: book.author,
          intro: '本地 EPUB · ${book.chapters.length} 章 · ${_size(bytes.length)}',
          sourceUrl: sourceUrl,
          sourceName: sourceName,
          type: 0,
          totalChapters: chapters.length,
          latestChapter: chapters.last.title,
          createdTime: DateTime.now().millisecondsSinceEpoch,
        ),
        chapters: chapters,
      );
    }

    final String text = _decodeText(bytes);
    final String name = '$stamp.txt';
    final File copy = File(p.join(dir.path, name));
    await copy.writeAsString(text, encoding: utf8, flush: true);
    final List<_Chunk> chunks = _splitTxt(text);
    final List<BookChapter> chapters = <BookChapter>[
      for (int i = 0; i < chunks.length; i++)
        BookChapter(title: chunks[i].title, url: 'txt://$i', index: i),
    ];
    return LocalImportResult(
      book: ShelfBook(
        bookUrl: '$_prefix$name',
        name: title,
        intro: '本地 TXT · ${chapters.length} 章 · ${_size(bytes.length)}',
        sourceUrl: sourceUrl,
        sourceName: sourceName,
        type: 0,
        totalChapters: chapters.length,
        latestChapter: chapters.isEmpty ? '' : chapters.last.title,
        createdTime: DateTime.now().millisecondsSinceEpoch,
      ),
      chapters: chapters,
    );
  }

  // ---------------------------------------------------------------- chapters

  /// 重新解析目录（本地书不会变，主要给「缓存丢了」的场景兜底）。
  Future<List<BookChapter>> chapters(ShelfBook book) async {
    final File file = await _fileOf(book);
    if (p.extension(file.path).toLowerCase() == '.epub') {
      return (await _loadEpub(file)).toChapters();
    }
    final List<_Chunk> chunks = _splitTxt(await file.readAsString(encoding: utf8));
    return <BookChapter>[
      for (int i = 0; i < chunks.length; i++)
        BookChapter(title: chunks[i].title, url: 'txt://$i', index: i),
    ];
  }

  Future<BookContent> content(ShelfBook book, BookChapter chapter) async {
    final File file = await _fileOf(book);
    if (chapter.url.startsWith('epub://')) {
      final _Epub epub = await _loadEpub(file);
      final String href = chapter.url.substring('epub://'.length);
      for (final _EpubChapter c in epub.chapters) {
        if (c.href == href) {
          return BookContent(
            text: c.text,
            images: const <String>[],
            nextUrl: '',
            title: c.title,
          );
        }
      }
      return const BookContent(
        text: '（这一节在文件里找不到了）',
        images: <String>[],
        nextUrl: '',
        title: '',
      );
    }

    final String text = await file.readAsString(encoding: utf8);
    final List<_Chunk> chunks = _splitTxt(text);
    final int index =
        chapter.index >= 0 && chapter.index < chunks.length ? chapter.index : 0;
    final _Chunk chunk = chunks[index];
    return BookContent(
      text: chunk.body,
      images: const <String>[],
      nextUrl: '',
      title: chunk.title,
    );
  }

  Future<File> _fileOf(ShelfBook book) async {
    final Directory dir = await _home();
    final String name = book.bookUrl.startsWith(_prefix)
        ? book.bookUrl.substring(_prefix.length)
        : book.bookUrl;
    final File file = File(p.join(dir.path, name));
    if (!file.existsSync()) {
      throw StateError('本地文件不见了：$name（重新导入一次吧）');
    }
    return file;
  }

  // ------------------------------------------------------------------- epub

  String? _cachedEpubKey;
  _Epub? _cachedEpub;

  Future<_Epub> _loadEpub(File file) async {
    final String key = '${file.path}@${file.statSync().modified.millisecondsSinceEpoch}';
    final _Epub? cached = _cachedEpub;
    if (cached != null && _cachedEpubKey == key) return cached;
    final _Epub parsed = _parseEpub(await file.readAsBytes());
    _cachedEpubKey = key;
    _cachedEpub = parsed;
    return parsed;
  }

  _Epub _parseEpub(Uint8List bytes) {
    final Archive archive = ZipDecoder().decodeBytes(bytes, verify: false);
    final Map<String, ArchiveFile> files = <String, ArchiveFile>{};
    for (final ArchiveFile f in archive.files) {
      if (f.isFile) files[f.name] = f;
    }

    String? opfPath;
    final ArchiveFile? container = files['META-INF/container.xml'];
    if (container != null) {
      final String xml = utf8.decode(container.content, allowMalformed: true);
      opfPath = RegExp(r'full-path\s*=\s*"([^"]+)"').firstMatch(xml)?.group(1);
    }
    opfPath ??= _firstWhereOrNull(
        files.keys, (String k) => k.toLowerCase().endsWith('.opf'));
    final ArchiveFile? opf = opfPath == null ? null : files[opfPath];
    if (opf == null) throw const FormatException('EPUB 缺少 OPF 文件');

    final String opfXml = utf8.decode(opf.content, allowMalformed: true);
    final String opfDir = p.url.dirname(opfPath!);

    final Map<String, String> manifest = <String, String>{};
    for (final RegExpMatch m in RegExp(r'<item\b[^>]*>').allMatches(opfXml)) {
      final String tag = m.group(0)!;
      final String id = _attr(tag, 'id');
      final String href = _attr(tag, 'href');
      if (id.isNotEmpty && href.isNotEmpty) manifest[id] = href;
    }

    final List<String> order = <String>[];
    for (final RegExpMatch m in RegExp(r'<itemref\b[^>]*>').allMatches(opfXml)) {
      final String idref = _attr(m.group(0)!, 'idref');
      final String? href = manifest[idref];
      if (href != null) order.add(href);
    }
    if (order.isEmpty) order.addAll(manifest.values);

    final List<_EpubChapter> chapters = <_EpubChapter>[];
    for (final String href in order) {
      final String full =
          opfDir.isEmpty || opfDir == '.' ? href : p.url.normalize(p.url.join(opfDir, href));
      final ArchiveFile? entry = files[full];
      if (entry == null) continue;
      final String html = CharsetUtil.decode(entry.content);
      final String heading = _headingOf(html);
      String text = htmlToPlainText(html).trim();
      // 标题行同时出现在 <h1> 和正文开头时，正文里去掉一次，免得阅读器重复
      if (heading.isNotEmpty && text.startsWith(heading)) {
        text = text.substring(heading.length).trim();
      }
      if (text.length < 20) continue; // 封面页/版权页之类，别当章节
      chapters.add(_EpubChapter(
        href: full,
        title: heading.isEmpty ? p.url.basenameWithoutExtension(full) : heading,
        text: text,
      ));
    }

    return _Epub(
      title: _meta(opfXml, 'dc:title'),
      author: _meta(opfXml, 'dc:creator'),
      chapters: chapters,
    );
  }

  static String _attr(String tag, String name) =>
      RegExp('$name\\s*=\\s*"([^"]*)"').firstMatch(tag)?.group(1) ??
      RegExp("$name\\s*=\\s*'([^']*)'").firstMatch(tag)?.group(1) ??
      '';

  static String _meta(String xml, String tag) {
    final Match? m = RegExp('<$tag[^>]*>([^<]*)</$tag>').firstMatch(xml);
    return m == null ? '' : _unescape(m.group(1)!.trim());
  }

  static String _headingOf(String html) {
    final dom.Document doc = html_parser.parse(html);
    for (final String sel in <String>['h1', 'h2', 'h3', 'title']) {
      final String text = doc.querySelector(sel)?.text.trim() ?? '';
      if (text.isNotEmpty && text.length <= 60) return _unescape(text);
    }
    return '';
  }

  /// `Iterable.firstOrNull` 要引 package:collection，这里不想为一行加依赖。
  static String? _firstWhereOrNull(
    Iterable<String> items,
    bool Function(String) test,
  ) {
    for (final String item in items) {
      if (test(item)) return item;
    }
    return null;
  }

  static String _unescape(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ');

  // -------------------------------------------------------------------- txt

  static const List<String> _titlePatterns = <String>[
    r'^[ \t\u3000]*(第[0-9零一二三四五六七八九十百千万两]{1,12}[章节回卷篇][^\n]{0,40})$',
    r'^[ \t\u3000]*(卷[0-9零一二三四五六七八九十百千万两]{1,12}[^\n]{0,40})$',
    r'^[ \t\u3000]*(?:Chapter|CHAPTER)\s+[0-9IVXLCivxlc]+[^\n]{0,60}$',
    r'^[ \t\u3000]*[0-9]{1,4}[.、．][ \t\u3000]?[^\n]{1,30}$',
  ];

  static final List<RegExp> _titleRes = <RegExp>[
    for (final String ptn in _titlePatterns) RegExp(ptn, multiLine: true),
  ];

  /// 把整本 TXT 切成章节。切不出来就退化成单章「全文」。
  static List<_Chunk> _splitTxt(String raw) {
    final String text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final Map<int, RegExpMatch> marks = <int, RegExpMatch>{};
    for (final RegExp re in _titleRes) {
      for (final RegExpMatch m in re.allMatches(text)) {
        marks.putIfAbsent(m.start, () => m);
      }
    }
    if (marks.isEmpty) {
      return <_Chunk>[_Chunk('全文', text.trim())];
    }
    final List<RegExpMatch> sorted = marks.values.toList()
      ..sort((RegExpMatch a, RegExpMatch b) => a.start.compareTo(b.start));

    final List<_Chunk> out = <_Chunk>[];
    if (sorted.first.start > 0) {
      final String head = text.substring(0, sorted.first.start).trim();
      if (head.length > 10) out.add(_Chunk('前言', head));
    }
    for (int i = 0; i < sorted.length; i++) {
      final RegExpMatch m = sorted[i];
      final int end = i + 1 < sorted.length ? sorted[i + 1].start : text.length;
      final String title = m.group(0)!.trim();
      final String body = text.substring(m.end, end).trim();
      out.add(_Chunk(title.isEmpty ? '第 ${i + 1} 节' : title, body));
    }
    return out;
  }

  // ------------------------------------------------------------------ misc

  static String _decodeText(Uint8List bytes) {
    try {
      return const Utf8Decoder().convert(bytes);
    } on FormatException {
      // 国内 TXT 大量是 GBK/GB18030，交给 charset 嗅探
      return CharsetUtil.decode(bytes);
    }
  }

  static bool _looksLikeZip(Uint8List bytes) =>
      bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B;

  static String _size(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  static String _friendly(Object e) {
    final String s = e.toString();
    return s.startsWith('Exception: ') ? s.substring(11) : s;
  }
}

class _Chunk {
  const _Chunk(this.title, this.body);

  final String title;
  final String body;
}

class _Epub {
  const _Epub({required this.title, required this.author, required this.chapters});

  final String title;
  final String author;
  final List<_EpubChapter> chapters;

  List<BookChapter> toChapters() => <BookChapter>[
        for (int i = 0; i < chapters.length; i++)
          BookChapter(
            title: chapters[i].title,
            url: 'epub://${chapters[i].href}',
            index: i,
          ),
      ];
}

class _EpubChapter {
  const _EpubChapter({required this.href, required this.title, required this.text});

  final String href;
  final String title;
  final String text;
}
