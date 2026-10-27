import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../core/rule_exception.dart';
import '../model/book_info.dart';
import '../model/book_source.dart';
import '../model/search_book.dart';
import '../net/http_service.dart';

/// 哔咔漫画（picacomic）内置源。
///
/// 它没法用纯 JSON 规则表达，原因有两个：
/// 1. 每个请求都要带 `signature`，而签名把「时间戳 + nonce + 方法 + 路径」
///    一起算进 HMAC-SHA256，等于每个 URL 的 header 都不一样；
/// 2. 必须先登录拿 `authorization` token，且 token 要跨请求复用。
/// 所以这里用原生 Dart 实现，书源只需要写 `pica://` 开头的 URL 就能命中。
class PicaSource {
  PicaSource(this.http, {this.baseUrl = base});

  final HttpService http;

  /// 测试时可以指向本地假服务器。
  final String baseUrl;

  static const String apiKey = 'C69BAF41DA5ABD1FFEDC6D2F1E56A964';
  static const String apiSecret =
      r'~d}$Q7$eIni=V)9\RK/P.RM4;9[7|@/CA}b~OW!h|3Rd|@b|wz|r';
  static const String base = 'https://picaapi.picacomic.com';
  static const String imageBase = 'https://storage1.picacomic.com/static/';
  static const String appVersion = '2.2.1.3.3.4';
  static const String scheme = 'pica://';

  String? token;
  String uuid = 'webUUID';

  static bool matches(BookSource s) =>
      s.url.trim().toLowerCase().startsWith(scheme);

  /// `pica://comic/<id>` → `<id>`
  static String idOf(String url) {
    final String u = url.trim();
    if (!u.toLowerCase().startsWith(scheme)) return '';
    final String rest = u.substring(scheme.length);
    final List<String> parts =
        rest.split('/').where((String e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.first == 'comic' && parts.length > 1) return parts[1];
    return parts.first;
  }

  static String comicUrl(String id) => '${scheme}comic/$id';
  static String chapterUrl(String id, int order) =>
      '${scheme}comic/$id/$order';

  String _nonce() {
    const String hex = '0123456789abcdef';
    final Random r = Random.secure();
    return List<String>.generate(32, (_) => hex[r.nextInt(16)]).join();
  }

  /// 签名：piKey + timestamp + nonce + METHOD + path 的 HMAC-SHA256。
  String sign(String method, String path, String ts, String nonce) {
    final String raw = '$apiKey$ts$nonce${method.toUpperCase()}$path';
    return Hmac(sha256, utf8.encode(apiSecret))
        .convert(utf8.encode(raw))
        .toString();
  }

  Map<String, String> _headers(String method, String path) {
    final String ts =
        (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final String nonce = _nonce();
    return <String, String>{
      'api-key': apiKey,
      'nonce': nonce,
      'timestamp': ts,
      'signature': sign(method, path, ts, nonce),
      'accept': 'application/vnd.picacomic.com.v1+json',
      'app-channel': '3',
      'app-build-version': '45',
      'app-platform': 'android',
      'app-version': appVersion,
      'app-uuid': uuid,
      'image-quality': 'original',
      'User-Agent': 'okhttp/3.10.0',
      if (token != null && token!.isNotEmpty) 'authorization': token!,
    };
  }

  /// 发请求并把 JSON 解出来；`code != 200` 一律抛 [RuleException]。
  Future<Map<String, dynamic>> _call(
    String path, {
    String method = 'GET',
    String? body,
  }) async {
    final HttpResult res = await http.request(
      '$baseUrl$path',
      method: method,
      headers: <String, String>{
        ..._headers(method, path),
        if (body != null) 'Content-Type': 'application/json; charset=UTF-8',
      },
      body: body,
    );
    Map<String, dynamic>? map;
    try {
      final Object? decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) map = decoded;
    } on Object {
      map = null;
    }
    if (map == null) {
      throw RuleException('哔咔返回的不是 JSON（HTTP ${res.statusCode}）',
          detail: res.body.length > 200 ? res.body.substring(0, 200) : res.body);
    }
    final Object? code = map['code'];
    if (res.statusCode != 200 || (code is int && code != 200)) {
      final String msg = '${map['message'] ?? ''} ${map['error'] ?? ''}'.trim();
      if (res.statusCode == 401 || (code is int && code == 401)) {
        throw RuleException('哔咔登录状态失效，请重新登录',
            detail: msg.isEmpty ? null : msg);
      }
      throw RuleException('哔咔接口报错：${msg.isEmpty ? res.statusCode : msg}');
    }
    final Object? data = map['data'];
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  /// 登录换 token。成功后 token 留在本对象里，由调用方持久化。
  Future<String> signIn(String email, String password) async {
    final Map<String, dynamic> data = await _call(
      '/auth/sign-in',
      method: 'POST',
      body: jsonEncode(<String, String>{
        'email': email.trim(),
        'password': password,
      }),
    );
    final Object? t = data['token'];
    if (t is! String || t.isEmpty) {
      throw RuleException('哔咔登录没有返回 token');
    }
    token = t;
    return t;
  }

  /// 验证 token 是否可用（拿自己的资料）。
  Future<String> me() async {
    final Map<String, dynamic> data = await _call('/users/profile');
    final Object? u = data['user'];
    if (u is Map<String, dynamic>) return '${u['name'] ?? ''}'.trim();
    return '';
  }

  Future<List<SearchBook>> search(
    BookSource source,
    String keyword, {
    int page = 1,
  }) async {
    final String path =
        '/comics?page=$page&keyword=${Uri.encodeQueryComponent(keyword)}';
    final Map<String, dynamic> data = await _call(path);
    final Object? comics = data['comics'];
    if (comics is! List) return <SearchBook>[];
    final List<SearchBook> out = <SearchBook>[];
    for (final Object? item in comics) {
      if (item is! Map<String, dynamic>) continue;
      final String id = '${item['_id'] ?? ''}';
      final String name = '${item['title'] ?? ''}'.trim();
      if (id.isEmpty || name.isEmpty) continue;
      out.add(SearchBook(
        name: name,
        bookUrl: comicUrl(id),
        sourceUrl: source.url,
        sourceName: source.name,
        author: '${item['author'] ?? ''}'.trim(),
        cover: _thumb(item['thumb']),
        intro: '${item['description'] ?? ''}'.trim(),
        kind: _joinList(item['categories']),
      ));
    }
    return out;
  }

  Future<BookInfo> bookInfo(BookSource source, String url) async {
    final String id = idOf(url);
    if (id.isEmpty) throw RuleException('哔咔书籍地址不合法：$url');
    final Map<String, dynamic> data = await _call('/comics/$id');
    final Object? comic = data['comic'];
    if (comic is! Map<String, dynamic>) {
      throw RuleException('哔咔没有这部漫画的数据');
    }
    return BookInfo(
      name: '${comic['title'] ?? ''}'.trim(),
      bookUrl: comicUrl(id),
      author: '${comic['author'] ?? ''}'.trim(),
      intro: '${comic['description'] ?? ''}'.trim(),
      cover: _thumb(comic['thumb']),
      kind: _joinList(comic['categories']),
      tocUrl: comicUrl(id),
      lastChapter: '${comic['updated_at'] ?? ''}'.trim(),
    );
  }

  Future<List<BookChapter>> chapters(BookSource source, BookInfo info) async {
    final String id = idOf(info.bookUrl.isEmpty ? info.name : info.bookUrl);
    if (id.isEmpty) throw RuleException('哔咔书籍地址不合法：${info.bookUrl}');
    final List<BookChapter> out = <BookChapter>[];
    int page = 1;
    int pages = 1;
    while (page <= pages && page <= 200) {
      final Map<String, dynamic> data =
          await _call('/comics/$id/order?page=$page');
      final Object? eps = data['eps'];
      if (eps is! Map<String, dynamic>) break;
      final Object? docs = eps['docs'];
      if (docs is List) {
        for (final Object? item in docs) {
          if (item is! Map<String, dynamic>) continue;
          final int order =
              item['order'] is int ? item['order'] as int : out.length + 1;
          final String title = '${item['title'] ?? ''}'.trim();
          out.add(BookChapter(
            title: title.isEmpty ? '第$order话' : title,
            url: chapterUrl(id, order),
            index: out.length,
          ));
        }
      }
      final Object? p = eps['pages'];
      pages = p is int ? p : 1;
      page++;
    }
    // 哔咔返回的顺序就是 1..N，不再反转。
    return out;
  }

  Future<BookContent> content(BookSource source, BookChapter chapter) async {
    final String id = idOf(chapter.url);
    final List<String> parts = chapter.url.trim().split('/');
    final int order = int.tryParse(parts.last) ?? 0;
    if (id.isEmpty || order <= 0) {
      throw RuleException('哔咔章节地址不合法：${chapter.url}');
    }
    final List<String> images = <String>[];
    int page = 1;
    int pages = 1;
    while (page <= pages && page <= 60) {
      final Map<String, dynamic> data =
          await _call('/comics/$id/order/$order/pages?page=$page');
      final Object? p = data['pages'];
      if (p is! Map<String, dynamic>) break;
      final Object? docs = p['docs'];
      if (docs is List) {
        for (final Object? item in docs) {
          if (item is! Map<String, dynamic>) continue;
          String path = '';
          final Object? media = item['media'];
          if (media is Map<String, dynamic>) {
            path = '${media['path'] ?? ''}'.trim();
          }
          if (path.isEmpty) path = '${item['path'] ?? ''}'.trim();
          if (path.isEmpty) continue;
          images.add(path.startsWith('http') ? path : '$imageBase$path');
        }
      }
      final Object? total = p['pages'];
      pages = total is int ? total : 1;
      page++;
    }
    return BookContent(
      images: images,
      title: chapter.title,
      referer: '$base/',
    );
  }

  String _thumb(Object? thumb) {
    if (thumb is! Map<String, dynamic>) return '';
    String path = '${thumb['path'] ?? ''}'.trim();
    if (path.isEmpty) path = '${thumb['file'] ?? ''}'.trim();
    if (path.isEmpty) return '';
    return path.startsWith('http') ? path : '$imageBase$path';
  }

  String _joinList(Object? list) {
    if (list is List) {
      return list
          .map((Object? e) => '$e'.trim())
          .where((String e) => e.isNotEmpty)
          .join(' ');
    }
    return '';
  }
}
