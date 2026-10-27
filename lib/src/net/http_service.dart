import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';

import '../core/charset_util.dart';
import '../core/rule_exception.dart';
import 'rate_limiter.dart';

/// 一次 HTTP 请求的结果。
class HttpResult {
  const HttpResult({
    required this.body,
    required this.url,
    required this.statusCode,
  });

  final String body;

  /// 重定向之后的最终地址（解析相对链接时要用它）。
  final String url;
  final int statusCode;

  bool get isOk => statusCode >= 200 && statusCode < 400;
}

/// 统一的网络层：自动处理编码、Cookie、重定向、超时与「按域名限速」。
class HttpService {
  HttpService({CookieJar? cookieJar, RateLimiter? limiter, this.timeout})
      : limiter = limiter ?? RateLimiter() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 15),
        followRedirects: true,
        maxRedirects: 5,
        responseType: ResponseType.bytes,
        validateStatus: (int? code) => code != null && code < 500,
        headers: <String, String>{
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/120.0 Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        },
      ),
    );
    _jar = cookieJar ?? CookieJar();
    _dio.interceptors.add(CookieManager(_jar));
  }

  late final Dio _dio;
  late final CookieJar _jar;

  /// 按域名限速（书源的 `concurrentRate` 会通过它生效）。
  final RateLimiter limiter;

  /// 整体超时（连接 + 接收）。为 null 时用 Dio 默认值（15s/30s）。
  /// 批量体检书源时会设成几秒，避免一个死站拖住整轮扫描。
  final Duration? timeout;

  CookieJar get cookieJar => _jar;

  /// 见过的域名：Cookie 落盘时按域名逐个导出。
  final Set<String> _hosts = <String>{};

  /// Cookie 落盘路径。设了才持久化（App 启动时设成 appSupport/cookies.json）。
  ///
  /// 为什么值得存：Cloudflare 的 `cf_clearance`、站点登录态、搜索 session
  /// 都是一次性拿到的，丢掉就得重新过验证/重新登录。存下来下次启动直接复用，
  /// 直到它自己过期。
  String? cookieFile;

  /// 收到 Set-Cookie 时回调（App 层用来节流落盘）。
  void Function()? onCookiesChanged;

  Future<void> loadCookies() async {
    final String? path = cookieFile;
    if (path == null) return;
    try {
      final File f = File(path);
      if (!await f.exists()) return;
      final Object? decoded = jsonDecode(await f.readAsString());
      if (decoded is! List) return;
      final Map<String, List<Cookie>> byHost = <String, List<Cookie>>{};
      for (final Object? item in decoded) {
        if (item is! Map) continue;
        final String host = '${item['host'] ?? ''}';
        final String name = '${item['name'] ?? ''}';
        if (host.isEmpty || name.isEmpty) continue;
        final Cookie c = Cookie(name, '${item['value'] ?? ''}');
        final Object? domain = item['domain'];
        if (domain is String && domain.isNotEmpty) c.domain = domain;
        final Object? cpath = item['path'];
        if (cpath is String && cpath.isNotEmpty) c.path = cpath;
        c.secure = item['secure'] == true;
        c.httpOnly = item['httpOnly'] == true;
        final Object? exp = item['expires'];
        if (exp is int) c.expires = DateTime.fromMillisecondsSinceEpoch(exp);
        byHost.putIfAbsent(host, () => <Cookie>[]).add(c);
        _hosts.add(host);
      }
      for (final MapEntry<String, List<Cookie>> e in byHost.entries) {
        await _jar.saveFromResponse(Uri.parse('https://${e.key}/'), e.value);
      }
    } on Object {
      // Cookie 文件坏了不该拦住启动。
    }
  }

  Future<void> saveCookies() async {
    final String? path = cookieFile;
    if (path == null || _hosts.isEmpty) return;
    try {
      final List<Map<String, Object?>> out = <Map<String, Object?>>[];
      for (final String host in _hosts) {
        final List<Cookie> list =
            await _jar.loadForRequest(Uri.parse('https://$host/'));
        for (final Cookie c in list) {
          out.add(<String, Object?>{
            'host': host,
            'domain': c.domain,
            'path': c.path,
            'name': c.name,
            'value': c.value,
            'expires': c.expires?.millisecondsSinceEpoch,
            'secure': c.secure,
            'httpOnly': c.httpOnly,
          });
        }
      }
      final File f = File(path);
      await f.parent.create(recursive: true);
      await f.writeAsString(jsonEncode(out));
    } on Object {
      // 落盘失败不影响主流程。
    }
  }

  /// 响应是不是 Cloudflare / 人机验证页。
  static bool looksLikeChallenge(String text, Headers headers) {
    if ((headers.value('cf-mitigated') ?? '').toLowerCase() == 'challenge') {
      return true;
    }
    final String head =
        text.length > 4096 ? text.substring(0, 4096) : text;
    final String low = head.toLowerCase();
    if (low.contains('just a moment') ||
        low.contains('cf-browser-verification') ||
        low.contains('cf_chl_opt') ||
        low.contains('checking your browser') ||
        low.contains('enable javascript and cookies to continue')) {
      return true;
    }
    final String server = (headers.value('server') ?? '').toLowerCase();
    return server.contains('cloudflare') &&
        (low.contains('attention required') || low.contains('access denied'));
  }

  Future<HttpResult> request(
    String url, {
    String method = 'GET',
    Map<String, String>? headers,
    String? body,
    Map<String, dynamic>? query,
    String? charset,
  }) async {
    final Uri uri;
    try {
      uri = Uri.parse(url);
    } catch (e) {
      throw RuleException('URL 非法：$url', detail: e.toString());
    }
    if (!uri.hasScheme) {
      throw RuleException('URL 缺少协议：$url');
    }

    return limiter.run(
      uri.host,
      () => _send(uri, method, headers, body, query, charset),
    );
  }

  Future<HttpResult> _send(
    Uri uri,
    String method,
    Map<String, String>? headers,
    String? body,
    Map<String, dynamic>? query,
    String? charset,
  ) async {
    // 429/503 是纯节流信号，等一会儿重试就能过；别的错误不重试。
    const int maxAttempts = 3;
    for (int attempt = 1;; attempt++) {
      try {
        final HttpResult result =
            await _sendOnce(uri, method, headers, body, query, charset);
        final int code = result.statusCode;
        if ((code == 429 || code == 503) && attempt < maxAttempts) {
          await Future<void>.delayed(Duration(milliseconds: 1200 * attempt));
          continue;
        }
        return result;
      } on RuleException catch (e) {
        final bool throttled =
            e.message.contains('429') || e.message.contains('503');
        if (throttled && attempt < maxAttempts) {
          await Future<void>.delayed(Duration(milliseconds: 1200 * attempt));
          continue;
        }
        rethrow;
      }
    }
  }

  Future<HttpResult> _sendOnce(
    Uri uri,
    String method,
    Map<String, String>? headers,
    String? body,
    Map<String, dynamic>? query,
    String? charset,
  ) async {
    try {
      final bool isPost = method.toUpperCase() == 'POST';
      // GBK 站点提交中文表单必须按源声明字符集编码，否则服务端搜不到结果
      final Uint8List? bodyBytes =
          isPost && body != null ? CharsetUtil.encodeText(body, charset) : null;
      final Response<List<int>> resp = timeout == null
          ? await _dio.request<List<int>>(
              uri.toString(),
              data: !isPost ? null : (bodyBytes ?? body),
              queryParameters: query,
              options: _options(method, headers, charset, isPost, bodyBytes),
            )
          : await _dio
              .request<List<int>>(
                uri.toString(),
                data: !isPost ? null : (bodyBytes ?? body),
                queryParameters: query,
                options: _options(method, headers, charset, isPost, bodyBytes),
              )
              .timeout(timeout!);

      final List<int> data = resp.data ?? const <int>[];
      final String? contentType = resp.headers.value('content-type');
      final String text = CharsetUtil.decode(
        Uint8List.fromList(data),
        declared: charset ?? CharsetUtil.charsetFromContentType(contentType),
      );

      // 记录域名 + 提示 Cookie 有更新（App 层节流落盘）
      _hosts.add(uri.host);
      if (resp.headers.value('set-cookie') != null) onCookiesChanged?.call();

      final int code = resp.statusCode ?? 0;
      if ((code == 403 || code == 503 || code == 429) &&
          looksLikeChallenge(text, resp.headers)) {
        throw RuleException(
          '站点要求人机验证（Cloudflare），不是规则的问题',
          detail: '${uri.host} 返回了验证页。用浏览器打开该站过掉验证后，'
              '把 Cookie（如 cf_clearance=...）填进书源 JSON 的 header 里，'
              '墨町会把它存到本地复用，直到过期为止。',
        );
      }

      return HttpResult(
        body: text,
        url: resp.realUri.toString(),
        statusCode: resp.statusCode ?? 0,
      );
    } on TimeoutException {
      throw RuleException(
        '网络请求失败：超时（${timeout!.inSeconds}s）',
        detail: uri.toString(),
      );
    } on DioException catch (e) {
      throw RuleException(
        '网络请求失败：${_describe(e)}',
        detail: '${e.requestOptions.uri}',
      );
    }
  }

  Options _options(
    String method,
    Map<String, String>? headers,
    String? charset,
    bool isPost,
    Uint8List? bodyBytes,
  ) {
    final String? contentType = !isPost
        ? null
        : (headers?['Content-Type'] ??
            (charset != null
                ? 'application/x-www-form-urlencoded; charset=$charset'
                : 'application/x-www-form-urlencoded'));
    return Options(
      method: method.toUpperCase(),
      headers: isPost && charset != null && bodyBytes != null
          ? <String, String>{
              ...?headers,
              'Content-Type':
                  headers?['Content-Type'] ?? 'application/x-www-form-urlencoded; charset=$charset',
            }
          : headers,
      contentType: contentType,
    );
  }

  String _describe(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时';
      case DioExceptionType.receiveTimeout:
        return '读取超时';
      case DioExceptionType.sendTimeout:
        return '发送超时';
      case DioExceptionType.connectionError:
        return '连接失败';
      case DioExceptionType.badCertificate:
        return '证书错误';
      case DioExceptionType.cancel:
        return '已取消';
      case DioExceptionType.badResponse:
        return 'HTTP ${e.response?.statusCode}';
      default:
        return e.message ?? '未知错误';
    }
  }

  /// 下载图片字节（漫画用）。
  Future<Uint8List> imageBytes(
    String url, {
    Map<String, String>? headers,
  }) async {
    final Uri uri = Uri.parse(url);
    return limiter.run(uri.host, () async {
      final Response<List<int>> resp = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: headers,
          validateStatus: (int? code) => code != null && code < 400,
        ),
      );
      return Uint8List.fromList(resp.data ?? const <int>[]);
    });
  }

  void dispose() {
    _dio.close(force: true);
  }
}
