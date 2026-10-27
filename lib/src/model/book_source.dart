import 'dart:convert';

/// 书源内容类型。
class SourceType {
  static const int text = 0;
  static const int audio = 1;
  static const int image = 2; // 漫画
  static const int file = 3;

  static String label(int type) {
    switch (type) {
      case audio:
        return '有声';
      case image:
        return '漫画';
      case file:
        return '文件';
      default:
        return '小说';
    }
  }
}

String _s(Map<String, dynamic> m, String key, [String def = '']) {
  final Object? v = m[key];
  if (v == null) return def;
  if (v is String) return v;
  return v.toString();
}

int _i(Map<String, dynamic> m, String key, [int def = 0]) {
  final Object? v = m[key];
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? def;
  return def;
}

bool _b(Map<String, dynamic> m, String key, [bool def = false]) {
  final Object? v = m[key];
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final String s = v.toLowerCase();
    return s == 'true' || s == '1';
  }
  return def;
}

Map<String, dynamic> _map(Map<String, dynamic> m, String key) {
  final Object? v = m[key];
  if (v is Map) return v.map((Object? k, Object? val) => MapEntry(k.toString(), val));
  // 有些书源把规则存成 JSON 字符串（Legado 导出格式两种都有）
  if (v is String && v.trim().startsWith('{')) {
    try {
      final Object? decoded = jsonDecode(v);
      if (decoded is Map) {
        return decoded.map((Object? k, Object? val) => MapEntry(k.toString(), val));
      }
    } catch (_) {
      // 解析失败按空规则处理
    }
  }
  return const <String, dynamic>{};
}

/// 搜索 / 发现页规则。
class SearchRule {
  const SearchRule({
    this.bookList = '',
    this.name = '',
    this.author = '',
    this.intro = '',
    this.kind = '',
    this.lastChapter = '',
    this.updateTime = '',
    this.bookUrl = '',
    this.coverUrl = '',
    this.wordCount = '',
    this.checkKeyWord = '',
  });

  final String bookList;
  final String name;
  final String author;
  final String intro;
  final String kind;
  final String lastChapter;
  final String updateTime;
  final String bookUrl;
  final String coverUrl;
  final String wordCount;
  final String checkKeyWord;

  factory SearchRule.fromJson(Map<String, dynamic> j) => SearchRule(
        bookList: _s(j, 'bookList'),
        name: _s(j, 'name'),
        author: _s(j, 'author'),
        intro: _s(j, 'intro'),
        kind: _s(j, 'kind'),
        lastChapter: _s(j, 'lastChapter'),
        updateTime: _s(j, 'updateTime'),
        bookUrl: _s(j, 'bookUrl'),
        coverUrl: _s(j, 'coverUrl'),
        wordCount: _s(j, 'wordCount'),
        checkKeyWord: _s(j, 'checkKeyWord'),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'bookList': bookList,
        'name': name,
        'author': author,
        'intro': intro,
        'kind': kind,
        'lastChapter': lastChapter,
        'updateTime': updateTime,
        'bookUrl': bookUrl,
        'coverUrl': coverUrl,
        'wordCount': wordCount,
        'checkKeyWord': checkKeyWord,
      };
}

/// 详情页规则。
class BookInfoRule {
  const BookInfoRule({
    this.init = '',
    this.name = '',
    this.author = '',
    this.intro = '',
    this.kind = '',
    this.lastChapter = '',
    this.updateTime = '',
    this.coverUrl = '',
    this.tocUrl = '',
    this.wordCount = '',
    this.canReName = '',
    this.downloadUrls = '',
  });

  final String init;
  final String name;
  final String author;
  final String intro;
  final String kind;
  final String lastChapter;
  final String updateTime;
  final String coverUrl;
  final String tocUrl;
  final String wordCount;
  final String canReName;
  final String downloadUrls;

  factory BookInfoRule.fromJson(Map<String, dynamic> j) => BookInfoRule(
        init: _s(j, 'init'),
        name: _s(j, 'name'),
        author: _s(j, 'author'),
        intro: _s(j, 'intro'),
        kind: _s(j, 'kind'),
        lastChapter: _s(j, 'lastChapter'),
        updateTime: _s(j, 'updateTime'),
        coverUrl: _s(j, 'coverUrl'),
        tocUrl: _s(j, 'tocUrl'),
        wordCount: _s(j, 'wordCount'),
        canReName: _s(j, 'canReName'),
        downloadUrls: _s(j, 'downloadUrls'),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'init': init,
        'name': name,
        'author': author,
        'intro': intro,
        'kind': kind,
        'lastChapter': lastChapter,
        'updateTime': updateTime,
        'coverUrl': coverUrl,
        'tocUrl': tocUrl,
        'wordCount': wordCount,
        'canReName': canReName,
        'downloadUrls': downloadUrls,
      };
}

/// 目录规则。
class TocRule {
  const TocRule({
    this.chapterList = '',
    this.chapterName = '',
    this.chapterUrl = '',
    this.formatJs = '',
    this.isVolume = '',
    this.isVip = '',
    this.updateTime = '',
    this.nextTocUrl = '',
  });

  final String chapterList;
  final String chapterName;
  final String chapterUrl;
  final String formatJs;
  final String isVolume;
  final String isVip;
  final String updateTime;
  final String nextTocUrl;

  factory TocRule.fromJson(Map<String, dynamic> j) => TocRule(
        chapterList: _s(j, 'chapterList'),
        chapterName: _s(j, 'chapterName'),
        chapterUrl: _s(j, 'chapterUrl'),
        formatJs: _s(j, 'formatJs'),
        isVolume: _s(j, 'isVolume'),
        isVip: _s(j, 'isVip'),
        updateTime: _s(j, 'updateTime'),
        nextTocUrl: _s(j, 'nextTocUrl'),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'chapterList': chapterList,
        'chapterName': chapterName,
        'chapterUrl': chapterUrl,
        'formatJs': formatJs,
        'isVolume': isVolume,
        'isVip': isVip,
        'updateTime': updateTime,
        'nextTocUrl': nextTocUrl,
      };
}

/// 正文 / 图片列表规则。
class ContentRule {
  const ContentRule({
    this.content = '',
    this.nextContentUrl = '',
    this.webJs = '',
    this.sourceRegex = '',
    this.replaceRegex = '',
    this.imageStyle = '',
  });

  final String content;
  final String nextContentUrl;
  final String webJs;
  final String sourceRegex;
  final String replaceRegex;
  final String imageStyle;

  factory ContentRule.fromJson(Map<String, dynamic> j) => ContentRule(
        content: _s(j, 'content'),
        nextContentUrl: _s(j, 'nextContentUrl'),
        webJs: _s(j, 'webJs'),
        sourceRegex: _s(j, 'sourceRegex'),
        replaceRegex: _s(j, 'replaceRegex'),
        imageStyle: _s(j, 'imageStyle'),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'content': content,
        'nextContentUrl': nextContentUrl,
        'webJs': webJs,
        'sourceRegex': sourceRegex,
        'replaceRegex': replaceRegex,
        'imageStyle': imageStyle,
      };
}

/// 书源。字段名与「阅读」App 的 JSON 导出格式保持一致，
/// 这样可以直接导入别人分享的书源文件。
class BookSource {
  const BookSource({
    required this.url,
    required this.name,
    this.type = SourceType.text,
    this.group = '',
    this.enabled = true,
    this.weight = 0,
    this.comment = '',
    this.searchUrl = '',
    this.exploreUrl = '',
    this.header = const <String, String>{},
    this.loginUrl = '',
    this.jsLib = '',
    this.bookUrlPattern = '',
    this.enabledExplore = false,
    this.enabledCookieJar = true,
    this.concurrentRate = '',
    this.lastUpdateTime = '',
    this.ruleSearch = const SearchRule(),
    this.ruleExplore = const SearchRule(),
    this.ruleBookInfo = const BookInfoRule(),
    this.ruleToc = const TocRule(),
    this.ruleContent = const ContentRule(),
    this.raw = const <String, dynamic>{},
  });

  final String url;
  final String name;
  final int type;
  final String group;
  final bool enabled;
  final int weight;
  final String comment;
  final String searchUrl;
  final String exploreUrl;
  final Map<String, String> header;
  final String loginUrl;
  final String jsLib;
  final String bookUrlPattern;
  final bool enabledExplore;
  final bool enabledCookieJar;
  final String concurrentRate;
  final String lastUpdateTime;

  final SearchRule ruleSearch;
  final SearchRule ruleExplore;
  final BookInfoRule ruleBookInfo;
  final TocRule ruleToc;
  final ContentRule ruleContent;

  /// 原始 JSON，写回 / 导出时保留未识别字段。
  final Map<String, dynamic> raw;

  bool get isComic => type == SourceType.image;
  bool get isText => type == SourceType.text;
  bool get canSearch => searchUrl.trim().isNotEmpty;
  bool get hasExplore => exploreUrl.trim().isNotEmpty;

  /// 只换启用状态，其余原样（订阅更新时保留用户自己的开关）。
  BookSource copyWithEnabled(bool value) => BookSource(
        url: url,
        name: name,
        type: type,
        group: group,
        enabled: value,
        weight: weight,
        comment: comment,
        searchUrl: searchUrl,
        exploreUrl: exploreUrl,
        header: header,
        loginUrl: loginUrl,
        jsLib: jsLib,
        bookUrlPattern: bookUrlPattern,
        enabledExplore: enabledExplore,
        enabledCookieJar: enabledCookieJar,
        concurrentRate: concurrentRate,
        lastUpdateTime: lastUpdateTime,
        ruleSearch: ruleSearch,
        ruleExplore: ruleExplore,
        ruleBookInfo: ruleBookInfo,
        ruleToc: ruleToc,
        ruleContent: ruleContent,
        raw: raw,
      );

  /// 镜像站地址（我们自己扩展的字段 `mirrors`，Legado 导出里没有）。
  ///
  /// 同一个站常有多个域名轮换，主域被墙时按顺序换下一个；
  /// 内置了几组已知的对照组，书源 JSON 里写 `mirrors` 可以覆盖。
  List<String> get mirrors {
    final Object? declared = raw['mirrors'];
    if (declared is List) {
      return declared
          .map((Object? e) => '$e'.trim())
          .where((String s) => s.isNotEmpty && s != url)
          .toList();
    }
    if (declared is String && declared.trim().isNotEmpty) {
      return declared
          .split(RegExp(r'[\s,]+'))
          .map((String s) => s.trim())
          .where((String s) => s.isNotEmpty && s != url)
          .toList();
    }
    final String host = Uri.tryParse(url)?.host ?? '';
    return <String>[
      for (final String m in _builtinMirrors[host] ?? const <String>[])
        if (m != url && m != 'https://$host') m,
    ];
  }

  /// 已知镜像组（实测用过的那几组）。
  static const Map<String, List<String>> _builtinMirrors =
      <String, List<String>>{
    'baozimh.org': <String>['https://bzmh.org'],
    'bzmh.org': <String>['https://baozimh.org'],
    'www.baozimh.com': <String>['https://baozimh.org', 'https://bzmh.org'],
  };

  factory BookSource.fromJson(Map<String, dynamic> j) {
    final Map<String, String> header = <String, String>{};
    _map(j, 'header').forEach((String k, Object? v) {
      header[k] = v == null ? '' : v.toString();
    });
    return BookSource(
      url: _s(j, 'bookSourceUrl').trim(),
      name: _s(j, 'bookSourceName').trim(),
      type: _i(j, 'bookSourceType'),
      group: _s(j, 'bookSourceGroup'),
      enabled: _b(j, 'enabled', true),
      weight: _i(j, 'weight'),
      comment: _s(j, 'bookSourceComment'),
      searchUrl: _s(j, 'searchUrl'),
      exploreUrl: _s(j, 'exploreUrl'),
      header: header,
      loginUrl: _s(j, 'loginUrl'),
      jsLib: _s(j, 'jsLib'),
      bookUrlPattern: _s(j, 'bookUrlPattern'),
      enabledExplore: _b(j, 'enabledExplore'),
      enabledCookieJar: _b(j, 'enabledCookieJar', true),
      concurrentRate: _s(j, 'concurrentRate'),
      lastUpdateTime: _s(j, 'lastUpdateTime'),
      ruleSearch: SearchRule.fromJson(_map(j, 'ruleSearch')),
      ruleExplore: SearchRule.fromJson(_map(j, 'ruleExplore')),
      ruleBookInfo: BookInfoRule.fromJson(_map(j, 'ruleBookInfo')),
      ruleToc: TocRule.fromJson(_map(j, 'ruleToc')),
      ruleContent: ContentRule.fromJson(_map(j, 'ruleContent')),
      raw: j,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        ...raw,
        'bookSourceUrl': url,
        'bookSourceName': name,
        'bookSourceType': type,
        'bookSourceGroup': group,
        'enabled': enabled,
        'weight': weight,
        'bookSourceComment': comment,
        'searchUrl': searchUrl,
        'exploreUrl': exploreUrl,
        'header': header,
        'loginUrl': loginUrl,
        'jsLib': jsLib,
        'bookUrlPattern': bookUrlPattern,
        'enabledExplore': enabledExplore,
        'enabledCookieJar': enabledCookieJar,
        'concurrentRate': concurrentRate,
        'lastUpdateTime': lastUpdateTime,
        'ruleSearch': ruleSearch.toJson(),
        'ruleExplore': ruleExplore.toJson(),
        'ruleBookInfo': ruleBookInfo.toJson(),
        'ruleToc': ruleToc.toJson(),
        'ruleContent': ruleContent.toJson(),
      };

  BookSource copyWith({bool? enabled, int? weight, String? group}) => BookSource(
        url: url,
        name: name,
        type: type,
        group: group ?? this.group,
        enabled: enabled ?? this.enabled,
        weight: weight ?? this.weight,
        comment: comment,
        searchUrl: searchUrl,
        exploreUrl: exploreUrl,
        header: header,
        loginUrl: loginUrl,
        jsLib: jsLib,
        bookUrlPattern: bookUrlPattern,
        enabledExplore: enabledExplore,
        enabledCookieJar: enabledCookieJar,
        concurrentRate: concurrentRate,
        lastUpdateTime: lastUpdateTime,
        ruleSearch: ruleSearch,
        ruleExplore: ruleExplore,
        ruleBookInfo: ruleBookInfo,
        ruleToc: ruleToc,
        ruleContent: ruleContent,
        raw: raw,
      );

  @override
  String toString() => 'BookSource($name, $url)';
}
