import 'book_source.dart';

/// 书籍详情（详情页解析结果）。
class BookInfo {
  const BookInfo({
    required this.name,
    required this.bookUrl,
    this.author = '',
    this.intro = '',
    this.kind = '',
    this.cover = '',
    this.lastChapter = '',
    this.updateTime = '',
    this.wordCount = '',
    this.tocUrl = '',
    this.type = SourceType.text,
  });

  final String name;
  final String author;
  final String intro;
  final String kind;
  final String cover;
  final String lastChapter;
  final String updateTime;
  final String wordCount;
  final String bookUrl;
  final String tocUrl;
  final int type;
}

/// 目录中的一章。
class BookChapter {
  const BookChapter({
    required this.title,
    required this.url,
    required this.index,
    this.isVip = false,
    this.isVolume = false,
  });

  final String title;
  final String url;
  final int index;
  final bool isVip;
  final bool isVolume;

  BookChapter copyWith({String? title, String? url, int? index}) => BookChapter(
        title: title ?? this.title,
        url: url ?? this.url,
        index: index ?? this.index,
        isVip: isVip,
        isVolume: isVolume,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'url': url,
        'index': index,
        'isVip': isVip,
        'isVolume': isVolume,
      };

  factory BookChapter.fromJson(Map<String, dynamic> j) => BookChapter(
        title: (j['title'] ?? '') as String,
        url: (j['url'] ?? '') as String,
        index: (j['index'] as num?)?.toInt() ?? 0,
        isVip: j['isVip'] == true,
        isVolume: j['isVolume'] == true,
      );
}

/// 正文内容：小说是纯文本，漫画是图片 URL 列表。
class BookContent {
  const BookContent({
    this.text = '',
    this.images = const <String>[],
    this.nextUrl = '',
    this.title = '',
    this.referer = '',
  });

  final String text;
  final List<String> images;
  final String nextUrl;
  final String title;

  /// 拉这批图片时该带的 Referer（图床要求的站点不同，mangabz 必须带，linovelib 不能带）。
  /// 由引擎按书源域名填，漫画阅读器读图时透传。
  final String referer;

  bool get isEmpty => text.isEmpty && images.isEmpty;
}
