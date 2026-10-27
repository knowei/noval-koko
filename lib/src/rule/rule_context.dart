import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// 规则求值的上下文。
///
/// [node] 可能是：
///  * [dom.Document]  整页 HTML
///  * [dom.Element]   列表项节点
///  * [Map] / [List]  JSON 节点
///  * [String]        纯文本（正则规则、JS 的 `result`）
class RuleContext {
  RuleContext({
    this.node,
    this.baseUrl = '',
    this.headers = const <String, String>{},
    this.sourceUrl = '',
    this.sourceName = '',
    this.pageHtml,
  });

  /// 整页 HTML 上下文。
  ///
  /// 接口返回 JSON 时（现在很多站点是纯 API），直接把 JSON 当节点，
  /// 这样 `@Json:$.data[*]` 这类规则能直接吃接口返回。
  factory RuleContext.page(
    String html, {
    String baseUrl = '',
    Map<String, String> headers = const <String, String>{},
    String sourceUrl = '',
    String sourceName = '',
  }) {
    dynamic node;
    final String trimmed = html.trimLeft();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        node = jsonDecode(trimmed);
      } catch (_) {
        node = null;
      }
    }
    if (node == null) {
      dom.Document? doc;
      try {
        doc = html_parser.parse(html);
      } catch (_) {
        doc = null;
      }
      node = doc;
    }
    return RuleContext(
      node: node,
      pageHtml: html,
      baseUrl: baseUrl,
      headers: headers,
      sourceUrl: sourceUrl,
      sourceName: sourceName,
    );
  }

  final dynamic node;
  final String baseUrl;
  final Map<String, String> headers;
  final String sourceUrl;
  final String sourceName;

  /// 整页 HTML 原文（元素上下文里用来还原完整页面）。
  final String? pageHtml;

  late final String text = _computeText();

  String _computeText() {
    final dynamic n = node;
    if (n == null) return pageHtml ?? '';
    if (n is String) return n;
    if (n is num || n is bool) return n.toString();
    if (n is dom.Element) {
      final String? r = pageHtml;
      return r ?? n.outerHtml;
    }
    if (n is dom.Document) {
      final String? r = pageHtml;
      return r ?? n.outerHtml;
    }
    if (n is Map || n is List) {
      try {
        return jsonEncode(n);
      } catch (_) {
        return n.toString();
      }
    }
    return n.toString();
  }

  RuleContext child(dynamic childNode) => RuleContext(
        node: childNode,
        baseUrl: baseUrl,
        headers: headers,
        sourceUrl: sourceUrl,
        sourceName: sourceName,
        pageHtml: childNode is String ? childNode : null,
      );
}
