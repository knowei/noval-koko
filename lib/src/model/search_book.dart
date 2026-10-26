import 'book_source.dart';

/// 搜索结果条目（尚未加入书架）。
class SearchBook {
  const SearchBook({
    required this.name,
    required this.bookUrl,
    required this.sourceUrl,
    required this.sourceName,
    this.author = '',
    this.cover = '',
    this.intro = '',
    this.kind = '',
    this.lastChapter = '',
    this.updateTime = '',
    this.wordCount = '',
    this.type = SourceType.text,
  });

  final String name;
  final String author;
  final String bookUrl;
  final String cover;
  final String intro;
  final String kind;
  final String lastChapter;
  final String updateTime;
  final String wordCount;
  final String sourceUrl;
  final String sourceName;
  final int type;

  SearchBook copyWith({
    String? name,
    String? author,
    String? cover,
    String? intro,
    String? kind,
    String? lastChapter,
    String? updateTime,
    String? wordCount,
  }) =>
      SearchBook(
        name: name ?? this.name,
        author: author ?? this.author,
        bookUrl: bookUrl,
        cover: cover ?? this.cover,
        intro: intro ?? this.intro,
        kind: kind ?? this.kind,
        lastChapter: lastChapter ?? this.lastChapter,
        updateTime: updateTime ?? this.updateTime,
        wordCount: wordCount ?? this.wordCount,
        sourceUrl: sourceUrl,
        sourceName: sourceName,
        type: type,
      );

  bool get isEmpty => name.isEmpty || bookUrl.isEmpty;
}
