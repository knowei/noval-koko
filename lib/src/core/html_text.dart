import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// 把正文 HTML 转成阅读器要用的纯文本（保留段落换行，丢掉脚本/样式）。
///
/// 书源里的 `@html` 规则拿到的是带标签的 HTML，Legado 由 WebView 渲染；
/// 我们的文本阅读器是自绘分页的，所以在进 UI 之前统一在这里拍平。
String htmlToPlainText(String html) {
  if (!html.contains('<') && !html.contains('&')) return html.trim();
  try {
    final dom.DocumentFragment frag = html_parser.parseFragment(html);
    final StringBuffer sb = StringBuffer();
    const Set<String> blocks = <String>{
      'p',
      'div',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
      'li',
      'tr',
      'section',
      'article',
      'blockquote',
      'pre',
    };

    void newline() {
      if (sb.isEmpty) return;
      if (!sb.toString().endsWith('\n')) sb.write('\n');
    }

    void walk(dom.Node n) {
      if (n is dom.Text) {
        sb.write(n.data);
        return;
      }
      if (n is dom.Element) {
        final String tag = (n.localName ?? '').toLowerCase();
        if (tag == 'br') {
          sb.write('\n');
          return;
        }
        if (tag == 'script' || tag == 'style') return;
        final bool block = blocks.contains(tag);
        if (block) newline();
        for (final dom.Node child in n.nodes) {
          walk(child);
        }
        if (block) newline();
        return;
      }
      for (final dom.Node child in n.nodes) {
        walk(child);
      }
    }

    for (final dom.Node child in frag.nodes) {
      walk(child);
    }

    String t = sb.toString();
    t = t.replaceAll('\u00A0', ' ');
    t = t.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    t = t.replaceAll(RegExp(r' *\n *'), '\n');
    t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return t.trim();
  } catch (_) {
    return html;
  }
}
