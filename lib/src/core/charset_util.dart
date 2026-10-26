import 'dart:convert';
import 'dart:typed_data';

import 'package:charset/charset.dart';

/// 字节流解码工具。
///
/// 解析顺序：UTF-8 BOM > 声明字符集（HTTP 头 / 调用方） > HTML meta > 严格 UTF-8
/// > 自动探测（GBK） > UTF-8 容错解码。
///
/// 中文小说/漫画站点大量使用 GBK/GB2312，必须按字节解码后再交给解析器，
/// 否则会出现乱码而无法用 CSS 选择器匹配。
class CharsetUtil {
  const CharsetUtil._();

  static const Map<String, String> _alias = <String, String>{
    'utf8': 'utf-8',
    'utf-8': 'utf-8',
    'unicode-1-1-utf-8': 'utf-8',
    'gb2312': 'gbk',
    'gb-2312': 'gbk',
    'gb_2312': 'gbk',
    'gbk': 'gbk',
    'gb18030': 'gbk',
    'cp936': 'gbk',
    'windows-936': 'gbk',
    'x-gbk': 'gbk',
    'big5': 'big5',
    'big-5': 'big5',
    'shift_jis': 'shift_jis',
    'shift-jis': 'shift_jis',
    'sjis': 'shift_jis',
    'x-sjis': 'shift_jis',
    'euc-jp': 'euc-jp',
    'eucjp': 'euc-jp',
    'euc-kr': 'euc-kr',
    'euckr': 'euc-kr',
    'iso-8859-1': 'iso-8859-1',
    'latin1': 'iso-8859-1',
  };

  /// 从响应头 `Content-Type: text/html; charset=gbk` 中提取字符集名。
  static String? charsetFromContentType(String? contentType) {
    if (contentType == null) return null;
    final m = RegExp(r'charset\s*=\s*"?([\w\-]+)', caseSensitive: false)
        .firstMatch(contentType);
    return m?.group(1);
  }

  static String decode(Uint8List bytes, {String? declared}) {
    if (bytes.isEmpty) return '';

    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }

    final String? name = _normalize(declared) ?? _sniffMeta(bytes);
    if (name != null) {
      final Encoding? enc = Charset.getByName(name);
      if (enc != null) {
        try {
          return enc.decode(bytes);
        } catch (_) {
          // 跳过，继续尝试其它方式
        }
      }
    }

    // 严格 UTF-8：合法就直接用，非法几乎必然是 GBK 站点。
    try {
      return utf8.decode(bytes);
    } catch (_) {
      // ignore
    }

    final Encoding? gbk = Charset.getByName('gbk');
    if (gbk != null) {
      try {
        return gbk.decode(bytes);
      } catch (_) {
        // ignore
      }
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  static String? _normalize(String? name) {
    if (name == null) return null;
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return null;
    return _alias[key] ?? key;
  }

  /// 按字符集名取 [Encoding]（GBK 站点提交表单、返回字节都需要它）。
  static Encoding? encodingOf(String? name) {
    final String? n = _normalize(name);
    if (n == null) return null;
    return Charset.getByName(n);
  }

  /// 把文本按指定字符集编码成字节；字符集未知或不支持时返回 null。
  static Uint8List? encodeText(String text, String? charset) {
    final Encoding? enc = encodingOf(charset);
    if (enc == null) return null;
    try {
      return Uint8List.fromList(enc.encode(text));
    } catch (_) {
      return null;
    }
  }

  /// 从 HTML 头部 4KB 内嗅探 `<meta charset>` / `content="text/html; charset=gbk"`。
  static String? _sniffMeta(Uint8List bytes) {
    final int end = bytes.length < 4096 ? bytes.length : 4096;
    final String head = latin1.decode(bytes.sublist(0, end), allowInvalid: true);
    final m = RegExp(
      r'''<meta[^>]+charset\s*=\s*["']?\s*([\w\-]+)''',
      caseSensitive: false,
    ).firstMatch(head);
    return m?.group(1);
  }
}
