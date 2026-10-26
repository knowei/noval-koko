/// 文本与 URL 小工具。
class TextUtil {
  const TextUtil._();

  /// 浏览器 UA：很多书站的图片/页面会按 UA 拦，直接 403。
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  /// 图片请求头。
  ///
  /// 实测（2026-10-26）：
  /// - 哔哩轻小说 linovelib 的图床被 Cloudflare 挡着：带 `Referer` 反而 403，
  ///   只要 UA + Accept + Accept-Language、**不带 Referer** 就 200（连测两轮稳定）；
  ///   用 `curl/x.y` 这类非常规 UA 也会 403。
  /// - 河豚图床 pic.hetunxs.com 无论怎么请求都连不上（站点侧问题）。
  /// 所以这里统一：浏览器 UA + 图片 Accept + Accept-Language，不发 Referer。
  static Map<String, String> imageHeaders(String url) => <String, String>{
        'User-Agent': userAgent,
        'Accept':
            'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      };

  static final RegExp _entityRe =
      RegExp(r'&(#[xX]?[0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]*);');
  static final RegExp _spacesRe = RegExp(r'[ \t\u00a0\u3000]+');
  static final RegExp _blankLineRe = RegExp(r'\n{3,}');

  static const Map<String, String> _named = <String, String>{
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",
    'nbsp': ' ',
    'ensp': ' ',
    'emsp': ' ',
    'hellip': '…',
    'mdash': '—',
    'ndash': '–',
    'ldquo': '“',
    'rdquo': '”',
    'lsquo': '‘',
    'rsquo': '’',
    'middot': '·',
    'bull': '•',
    'copy': '©',
    'reg': '®',
    'times': '×',
    'divide': '÷',
    'deg': '°',
  };

  /// 解码 HTML 实体（含数字实体）。
  static String unescapeHtml(String input) {
    if (!input.contains('&')) return input;
    return input.replaceAllMapped(_entityRe, (Match m) {
      final String body = m.group(1)!;
      if (body.startsWith('#')) {
        final bool hex =
            body.length > 1 && (body[1] == 'x' || body[1] == 'X');
        final int? code = int.tryParse(
          hex ? body.substring(2) : body.substring(1),
          radix: hex ? 16 : 10,
        );
        if (code == null) return m.group(0)!;
        try {
          return String.fromCharCode(code);
        } catch (_) {
          return m.group(0)!;
        }
      }
      return _named[body.toLowerCase()] ?? m.group(0)!;
    });
  }

  /// 压缩行内空白并去首尾空格。
  static String squeeze(String input) {
    var s = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    s = s.replaceAll(_spacesRe, ' ');
    s = s
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .join('\n');
    return s.replaceAll(_blankLineRe, '\n\n').trim();
  }

  /// 相对 URL 转绝对 URL。
  static String resolveUrl(String? baseUrl, String? href) {
    if (href == null) return '';
    final String h = href.trim();
    if (h.isEmpty) return '';
    if (h.startsWith('data:')) return h;
    // 站点里常见的占位链接，不是真的地址
    final String lower = h.toLowerCase();
    if (lower.startsWith('javascript:') ||
        lower.startsWith('vbscript:') ||
        lower == '#' ||
        lower.startsWith('#') ||
        lower.startsWith('void(')) {
      return '';
    }
    if (h.startsWith('http://') || h.startsWith('https://')) return h;
    if (baseUrl == null || baseUrl.isEmpty) return h;
    try {
      final Uri base = Uri.parse(baseUrl);
      return base.resolve(h).toString();
    } catch (_) {
      return h;
    }
  }

  /// 取 URL 的 scheme://host[:port]，用于拼接站点相对地址。
  static String hostOf(String url) {
    try {
      final Uri u = Uri.parse(url);
      if (!u.hasScheme) return '';
      return '${u.scheme}://${u.authority}';
    } catch (_) {
      return '';
    }
  }

  /// 判断一个值是否像链接（用于决定要不要做相对地址补全）。
  static bool looksLikeUrl(String value) {
    final String v = value.trim();
    return v.startsWith('http://') ||
        v.startsWith('https://') ||
        v.startsWith('//') ||
        (v.startsWith('/') && v.length > 1);
  }
}
