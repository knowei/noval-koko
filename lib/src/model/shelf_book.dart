import '../model/book_info.dart';
import '../model/book_source.dart';

/// 书架 / 目录里的一本书。
class ShelfBook {
  ShelfBook({
    required this.bookUrl,
    required this.name,
    this.author = '',
    this.cover = '',
    this.intro = '',
    this.kind = '',
    this.sourceUrl = '',
    this.sourceName = '',
    this.type = 0,
    this.tocUrl = '',
    this.totalChapters = 0,
    this.latestChapter = '',
    this.lastReadIndex = 0,
    this.lastReadOffset = 0,
    this.lastReadTime = 0,
    this.createdTime = 0,
  });

  final String bookUrl;
  final String name;

  /// 作者 / 封面 / 简介：搜索结果里经常是空的，等打开详情页拿到再回填。
  String author;
  String cover;
  String intro;
  final String kind;
  final String sourceUrl;
  final String sourceName;

  /// 0 = 文本，1 = 漫画
  final int type;
  final String tocUrl;
  int totalChapters;
  String latestChapter;
  int lastReadIndex;
  double lastReadOffset;
  int lastReadTime;
  final int createdTime;

  bool get isComic => type == SourceType.image;

  factory ShelfBook.fromInfo(
    BookInfo info, {
    required String sourceUrl,
    required String sourceName,
    required int type,
  }) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    return ShelfBook(
      bookUrl: info.bookUrl,
      name: info.name.isEmpty ? '未命名' : info.name,
      author: info.author,
      cover: info.cover,
      intro: info.intro,
      kind: info.kind,
      sourceUrl: sourceUrl,
      sourceName: sourceName,
      type: info.type != SourceType.text ? info.type : type,
      tocUrl: info.tocUrl,
      latestChapter: info.lastChapter,
      createdTime: now,
      lastReadTime: now,
    );
  }

  factory ShelfBook.fromMap(Map<String, Object?> m) => ShelfBook(
        bookUrl: (m['book_url'] as String?) ?? '',
        name: (m['name'] as String?) ?? '',
        author: (m['author'] as String?) ?? '',
        cover: _fixCover((m['cover'] as String?) ?? ''),
        intro: (m['intro'] as String?) ?? '',
        kind: (m['kind'] as String?) ?? '',
        sourceUrl: (m['source_url'] as String?) ?? '',
        sourceName: (m['source_name'] as String?) ?? '',
        type: (m['type'] as int?) ?? 0,
        tocUrl: (m['toc_url'] as String?) ?? '',
        totalChapters: (m['total_chapters'] as int?) ?? 0,
        latestChapter: (m['latest_chapter'] as String?) ?? '',
        lastReadIndex: (m['last_read_index'] as int?) ?? 0,
        lastReadOffset: ((m['last_read_offset'] as num?) ?? 0).toDouble(),
        lastReadTime: (m['last_read_time'] as int?) ?? 0,
        createdTime: (m['created_time'] as int?) ?? 0,
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'book_url': bookUrl,
        'name': name,
        'author': author,
        'cover': cover,
        'intro': intro,
        'kind': kind,
        'source_url': sourceUrl,
        'source_name': sourceName,
        'type': type,
        'toc_url': tocUrl,
        'total_chapters': totalChapters,
        'latest_chapter': latestChapter,
        'last_read_index': lastReadIndex,
        'last_read_offset': lastReadOffset,
        'last_read_time': lastReadTime,
        'created_time': createdTime,
      };
}

/// 老版本把相对地址当绝对地址拼过，库里会留下
/// `https://hosthttps://real-host/x.jpg` 这种废地址；这里自愈。
final RegExp _doubleScheme = RegExp(r'^https?://[^/]+(https?://.+)$');

String _fixCover(String raw) {
  final String s = raw.trim();
  if (s.isEmpty) return s;
  final RegExpMatch? m = _doubleScheme.firstMatch(s);
  return m == null ? s : m.group(1)!.trim();
}
