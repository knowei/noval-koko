import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../core/rule_exception.dart';
import '../core/text_util.dart';
import 'js_engine.dart';
import 'rule_context.dart';
import 'xpath_engine.dart';

/// 「阅读」App 书源规则的解析引擎。
///
/// 支持的规则语法（与 Legado 基本对齐）：
/// * `@css:选择器@text|html|href|attr` — CSS / jsoup 风格链式选择器
/// * `class.x@tag.y@text`            — jsoup 风格（`@` 作为「后代」连接）
/// * `@XPath://div/a/@href`          — XPath
/// * `@Json:$.data.list[*].name`     — JSONPath
/// * `:正则`                          — 正则取匹配
/// * `@js:脚本` / `{{表达式}}`        — JavaScript
/// * `规则##正则##替换`               — 结果替换（可多组）
/// * `规则A && 规则B`                — 结果拼接
/// * `规则A || 规则B`                — 取第一个非空结果
class RuleParser {
  RuleParser({this.js});

  /// JS 引擎。为空时 JS 规则会抛异常。
  final JsEngine? js;

  // ------------------------------------------------------------- public API

  /// 求值并返回原始节点列表（可能是 [dom.Element] / Map / List / String）。
  Future<List<dynamic>> evalList(String rule, RuleContext ctx) async {
    final String r = rule.trim();
    if (r.isEmpty) return const <dynamic>[];

    // 整条规则就是一段 JS 时，不要按 && / || 切分（那是 JS 的逻辑运算符）
    if (r.startsWith('@js:') || (r.startsWith('{{') && r.endsWith('}}'))) {
      return _evalCore(r, ctx);
    }

    final List<String> tokens = _splitLogical(r);
    List<dynamic> acc = const <dynamic>[];
    String? op;
    bool started = false;
    for (final String token in tokens) {
      final String term = token.trim();
      if (term == '&&' || term == '||') {
        op = term;
        continue;
      }
      if (term.isEmpty) {
        op = null;
        continue;
      }
      final List<dynamic> value = await _evalTerm(term, ctx);
      if (!started) {
        acc = value;
        started = true;
      } else if (op == '&&') {
        acc = <dynamic>[...acc, ...value];
      } else if (op == '||') {
        if (acc.isEmpty) acc = value;
      } else {
        acc = value;
      }
      op = null;
    }
    return acc;
  }

  /// 求值并拼接成字符串（多结果用换行连接）。
  Future<String> evalString(
    String rule,
    RuleContext ctx, {
    String def = '',
  }) async {
    final List<dynamic> list = await evalList(rule, ctx);
    final List<String> parts = <String>[];
    for (final dynamic v in list) {
      final String s = _asText(v);
      if (s.isNotEmpty) parts.add(s);
    }
    if (parts.isEmpty) return def;
    return parts.join('\n').trim();
  }

  /// 求值为 URL（相对路径会按 ctx.baseUrl 补全）。
  Future<String> evalUrl(String rule, RuleContext ctx, {String def = ''}) async {
    final String raw = await evalString(rule, ctx);
    if (raw.isEmpty) return def;
    return TextUtil.resolveUrl(ctx.baseUrl, raw);
  }

  /// 求值为 HTML 片段（正文规则用：元素取 innerHtml，保留段落结构）。
  Future<String> evalHtml(String rule, RuleContext ctx) async {
    final List<dynamic> list = await evalList(rule, ctx);
    final List<String> parts = <String>[];
    for (final dynamic v in list) {
      if (v is dom.Element) {
        final String html = v.innerHtml.trim();
        if (html.isNotEmpty) parts.add(html);
      } else {
        final String s = _asText(v);
        if (s.isNotEmpty) parts.add(s);
      }
    }
    return parts.join('\n').trim();
  }

  /// 求值为图片 URL 列表。
  Future<List<String>> evalImageList(String rule, RuleContext ctx) async {
    final List<String> raw = await evalList(rule, ctx)
        .then((List<dynamic> l) => l.map(_asText).toList());
    final List<String> out = <String>[];

    void add(String? candidate) {
      if (candidate == null) return;
      final String piece =
          candidate.trim().replaceAll('&amp;', '&').replaceAll('\\/', '/');
      if (piece.isEmpty) return;
      final String url = TextUtil.resolveUrl(ctx.baseUrl, piece);
      if (!url.startsWith('http')) return;
      if (!out.contains(url)) out.add(url);
    }

    // 漫画源常见写法：JS 直接拼一段 `<img src="...">` 的 HTML 返回。
    final RegExp imgTag = RegExp(
      r'''<img[^>]*?\s(?:data-src|data-original|data-echo|src)\s*=\s*["']?([^"'\s>]+)''',
      caseSensitive: false,
    );

    for (final String item in raw) {
      if (item.contains('<img')) {
        for (final RegExpMatch m in imgTag.allMatches(item)) {
          add(m.group(1));
        }
        continue;
      }
      // 有些规则会把多个地址塞进一个字符串
      for (final String piece in item.split(RegExp(r'[\s,]+'))) {
        add(piece);
      }
    }
    return out;
  }

  // ------------------------------------------------------------- rule terms

  Future<List<dynamic>> _evalTerm(String rule, RuleContext ctx) async {
    // Legado 里规则结尾的 `###` 表示「正则替换全部」（本引擎本来就替换全部），
    // 直接吃掉这个尾巴，否则它会被当成替换串的开头，出现多余的 '#'。
    String r = rule.trim();
    if (r.endsWith('###')) r = r.substring(0, r.length - 1);
    final List<String> parts = _splitTop(r, '##');
    final List<dynamic> value = await _evalCore(parts[0].trim(), ctx);
    if (parts.length <= 1) return value;

    final List<String> out = <String>[];
    for (final dynamic v in value) {
      String s = _asText(v);
      for (int i = 1; i < parts.length; i += 2) {
        final String pattern = parts[i];
        final String replacement = i + 1 < parts.length ? parts[i + 1] : '';
        if (pattern.isEmpty) continue;
        s = _applyReplace(s, pattern, replacement);
      }
      s = s.trim();
      if (s.isNotEmpty) out.add(s);
    }
    return out;
  }

  Future<List<dynamic>> _evalCore(String rule, RuleContext ctx) async {
    final String r = rule.trim();
    if (r.isEmpty) return const <dynamic>[];

    final String lower = r.toLowerCase();
    if (r.startsWith('@js:')) {
      return _evalJs(r.substring(4), ctx);
    }
    // Legado 里 JS 规则的另一种写法是 <js>...</js>
    if (lower.startsWith('<js>')) {
      return _evalJs(_stripJsTag(r), ctx);
    }
    if (r.startsWith('{{') && r.endsWith('}}')) {
      return _evalJs(r.substring(2, r.length - 2), ctx);
    }

    if (lower.startsWith('@xpath:') ||
        r.startsWith('//') ||
        lower.startsWith('id(')) {
      return _evalXPath(r, ctx);
    }
    if (lower.startsWith('@json:') ||
        r.startsWith(r'$.') ||
        r.startsWith(r'$[') ||
        r == r'$') {
      return _evalJson(r, ctx);
    }
    if (r.startsWith(':')) {
      return _evalRegex(r.substring(1), ctx);
    }
    if (lower.startsWith('@css:')) {
      return _evalCss(r.substring(5), ctx);
    }
    return _evalCss(r, ctx);
  }

  // ------------------------------------------------------------------- CSS

  /// 去掉 `<js>` / `</js>` 包裹（Legado 的另一种 JS 规则写法）。
  String _stripJsTag(String rule) {
    String code = rule.trim();
    if (code.toLowerCase().startsWith('<js>')) code = code.substring(4);
    if (code.toLowerCase().endsWith('</js>')) {
      code = code.substring(0, code.length - 5);
    }
    return code;
  }

  static const Set<String> _blockTags = <String>{
    'p', 'div', 'br', 'li', 'tr', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
    'section', 'article', 'blockquote', 'ul', 'ol', 'table', 'dd', 'dt',
    'pre', 'hr',
  };

  Future<List<dynamic>> _evalCss(String rule, RuleContext ctx) async {
    final dynamic node = ctx.node;
    final dynamic root;
    if (node is dom.Document || node is dom.Element) {
      root = node;
    } else {
      try {
        root = html_parser.parse(ctx.text);
      } catch (_) {
        return const <dynamic>[];
      }
    }

    final List<String> segs = _splitTop(rule, '@');

    // Legado 的索引切片写法：`span!0:3`（第 0~2 个）、`a!-1`（最后一个）、`a!1:`（从第 1 个到最后）
    _Slice? slice;
    final RegExp sliceRe = RegExp(r'!\s*(-?\d*)\s*(?::\s*(-?\d*)\s*)?$');
    for (int i = 0; i < segs.length; i++) {
      final RegExpMatch? m = sliceRe.firstMatch(segs[i]);
      if (m == null || m.group(0)!.trim() == '!') continue;
      final bool hasColon = m.group(0)!.contains(':');
      final String startText = (m.group(1) ?? '').trim();
      final String endText = (m.group(2) ?? '').trim();
      if (startText.isEmpty && endText.isEmpty) continue;
      slice = _Slice(
        startText.isEmpty ? 0 : int.parse(startText),
        hasColon && endText.isNotEmpty ? int.parse(endText) : null,
        single: !hasColon,
      );
      segs[i] = segs[i].substring(0, m.start).trim();
    }

    // 单段规则且不像选择器时，表示「对当前节点取值」：text / href / html …
    if (segs.length == 1) {
      final String only = segs.first.trim();
      if (node is dom.Element &&
          only.isNotEmpty &&
          !_isSelectorStep(only) &&
          !_bareTagNames.contains(only.toLowerCase()) &&
          !RegExp(r'^\d+$').hasMatch(only)) {
        return _extract(<dom.Element>[node], only, ctx);
      }
    }

    final List<String> steps = <String>[];
    final List<String> textFilters = <String>[];
    final List<_AttrFilter> attrFilters = <_AttrFilter>[];
    String? extractor;
    int? index;

    for (int i = 0; i < segs.length; i++) {
      final String seg = segs[i].trim();
      if (seg.isEmpty) continue;

      // jsoup 的 `text.下一页`：取文本包含该字串的元素（常用于分页链接）
      if (seg.startsWith('text.') && seg.length > 5) {
        textFilters.add(seg.substring(5));
        steps.add('*');
        continue;
      }

      if (i == 0) {
        steps.add(_stripAttrOps(_toCss(seg), attrFilters));
        continue;
      }
      if (_isSelectorStep(seg)) {
        final (String base, int? idx) = _maybeIndex(seg);
        steps.add(_stripAttrOps(_toCss(base), attrFilters));
        if (idx != null) index = idx;
        continue;
      }
      if (RegExp(r'^\d+$').hasMatch(seg)) {
        index = int.parse(seg);
        continue;
      }
      // 容错：允许把 `class.list@a` 里的 `a` 当成子元素选择器（标准写法是 tag.a）
      if (_bareTagNames.contains(seg.toLowerCase())) {
        steps.add(seg.toLowerCase());
        continue;
      }
      extractor = seg;
      break;
    }

    // jsoup 风格的第一个片段也可能带索引：class.book-list.0
    if (steps.length == 1 && _isJsoupStep(segs.first.trim())) {
      final (String base, int? idx) = _maybeIndex(segs.first.trim());
      steps[0] = _toCss(base);
      if (idx != null) index = idx;
    }

    final String css = steps.where((String s) => s.isNotEmpty).join(' ');
    if (css.trim().isEmpty) return const <dynamic>[];

    List<dom.Element> els;
    try {
      els = root is dom.Document
          ? root.querySelectorAll(css)
          : (root as dom.Element).querySelectorAll(css);
    } catch (_) {
      return const <dynamic>[];
    }
    if (els.isEmpty) return const <dynamic>[];
    if (attrFilters.isNotEmpty) {
      els = els.where((dom.Element e) {
        return attrFilters.every((_AttrFilter f) => f.match(e));
      }).toList();
      if (els.isEmpty) return const <dynamic>[];
    }
    if (textFilters.isNotEmpty) {
      els = els.where((dom.Element e) {
        final String t = _innerText(e);
        return textFilters.every(t.contains);
      }).toList();
      if (els.isEmpty) return const <dynamic>[];
    }
    if (index != null) {
      if (index < 0 || index >= els.length) return const <dynamic>[];
      els = <dom.Element>[els[index]];
    }
    if (slice != null) {
      els = _applySlice(els, slice);
      if (els.isEmpty) return const <dynamic>[];
    }

    if (extractor == null) return els;

    // 提取器本身是 JS：对每个元素以它的 outerHtml 作为 `result` 求值
    if (_isJsRule(extractor)) {
      final String code = extractor.startsWith('@js:')
          ? extractor.substring(4)
          : extractor.startsWith('{{')
              ? extractor.substring(2, extractor.length - 2)
              : _stripJsTag(extractor);
      final List<dynamic> out = <dynamic>[];
      for (final dom.Element el in els) {
        try {
          out.addAll(await _evalJs(code, ctx.child(el)));
        } catch (_) {
          // 单个元素求值失败不影响其它元素
        }
      }
      return out;
    }
    return _extract(els, extractor, ctx);
  }

  /// 规则片段是否是 JS（`@js:` / `<js>` / `{{ }}`）。
  bool _isJsRule(String s) {
    final String t = s.trim();
    return t.startsWith('@js:') ||
        t.toLowerCase().startsWith('<js>') ||
        (t.startsWith('{{') && t.endsWith('}}'));
  }

  /// 从元素列表里取出最终值（text / html / 属性名）。
  List<dynamic> _extract(
    List<dom.Element> els,
    String extractor,
    RuleContext ctx,
  ) {
    switch (extractor) {
      case 'text':
        return els
            .map((dom.Element e) => TextUtil.squeeze(_innerText(e)))
            .where((String s) => s.isNotEmpty)
            .toList();
      case 'ownText':
        return els
            .map((dom.Element e) => TextUtil.squeeze(
                  e.nodes
                      .whereType<dom.Text>()
                      .map((dom.Text t) => t.data)
                      .join(' '),
                ))
            .where((String s) => s.isNotEmpty)
            .toList();
      case 'textNodes':
        return els
            .expand((dom.Element e) => e.nodes
                .whereType<dom.Text>()
                .map((dom.Text t) => t.data.trim())
                .where((String s) => s.isNotEmpty))
            .toList();
      case 'html':
        return els.map((dom.Element e) => e.innerHtml).toList();
      case 'all':
      case 'outerHtml':
        return els.map((dom.Element e) => e.outerHtml).toList();
      default:
        break;
    }

    final String attr = extractor;
    final List<String> values = <String>[];
    for (final dom.Element el in els) {
      final String? v = el.attributes[attr];
      if (v == null) continue;
      final String value = TextUtil.unescapeHtml(v.trim());
      if (value.isEmpty) continue;
      // 这里**不**把 href / src 补成绝对地址：Legado 里 `##正则##替换`
      // 是作用在原始属性值上的（例如把 `/info-6/6485/` 改写成图床地址），
      // 提前补全会得到 `https://hosthttps://...` 这种废地址。
      // 需要绝对地址的调用方（bookUrl / coverUrl / nextTocUrl …）走 evalUrl，
      // 那边会在替换之后补全。
      values.add(value);
    }
    return values;
  }

  /// 常见的「裸标签名」步骤，用于容错处理 `id.list@a` 这类规则。
  static const Set<String> _bareTagNames = <String>{
    'a', 'b', 'i', 'u', 'p', 'em', 'li', 'ul', 'ol', 'tr', 'td', 'th',
    'dd', 'dt', 'dl', 'div', 'span', 'font', 'img', 'br', 'hr',
    'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'section', 'article', 'strong',
    'table', 'tbody', 'label', 'input', 'body',
  };

  bool _isJsoupStep(String s) =>
      s.startsWith('tag.') || s.startsWith('class.') || s.startsWith('id.');

  bool _isSelectorStep(String s) =>
      _isJsoupStep(s) ||
      s == 'children' ||
      s.startsWith('children.') ||
      s.startsWith('select.') ||
      s.startsWith('text.');

  /// jsoup 选择器片段 → CSS 选择器。
  String _toCss(String s) {
    final String t = s.trim();
    if (t.startsWith('tag.')) {
      final String rest = t.substring(4);
      return rest.isEmpty ? '*' : rest;
    }
    if (t.startsWith('class.')) {
      final String rest = t.substring(6);
      final String css = rest
          .split('.')
          .where((String e) => e.isNotEmpty)
          .map((String e) => '.$e')
          .join();
      return css.isEmpty ? '*' : css;
    }
    if (t.startsWith('id.')) {
      final String rest = t.substring(3);
      return rest.isEmpty ? '*' : '#$rest';
    }
    if (t.startsWith('text.')) {
      return '*';
    }
    if (t.startsWith('select.')) {
      return t.substring(7);
    }
    if (t == 'children') return '*';
    return t;
  }

  /// package:html 的 querySelector 不支持 `[attr*=value]` 这类运算符选择器，
  /// 这里把它们从 CSS 里摘出来，等节点取到之后再用 [_AttrFilter] 手工过滤。
  String _stripAttrOps(String css, List<_AttrFilter> out) {
    if (!css.contains('[')) return css;
    final String cleaned = css.replaceAllMapped(_attrOpRe, (Match m) {
      out.add(_AttrFilter(
        m.group(1)!.trim().toLowerCase(),
        m.group(2)!,
        (m.group(3) ?? '').trim(),
      ));
      return '';
    });
    return cleaned.trim().isEmpty ? '*' : cleaned;
  }

  static final RegExp _attrOpRe = RegExp(
    r'\[\s*([\w:-]+)\s*(\*=|\^=|\$=|~=|\|=)\s*"?([^\]]*?)"?\s*\]',
  );

  (String, int?) _maybeIndex(String s) {    if (!_isJsoupStep(s)) return (s, null);
    final RegExpMatch? m = RegExp(r'^(.*)\.(\d+)$').firstMatch(s);
    if (m == null) return (s, null);
    final String base = m.group(1)!;
    if (base.isEmpty) return (s, null);
    return (base, int.parse(m.group(2)!));
  }

  /// 取元素可见文本，块级标签自动换行。
  String _innerText(dom.Node node) {
    final StringBuffer sb = StringBuffer();
    void walk(dom.Node n) {
      if (n is dom.Text) {
        sb.write(n.data);
        return;
      }
      if (n is dom.Comment) return;
      if (n is dom.Element) {
        final String tag = (n.localName ?? '').toLowerCase();
        final bool block = _blockTags.contains(tag);
        if (block && sb.isNotEmpty && !sb.toString().endsWith('\n')) {
          sb.write('\n');
        }
        for (final dom.Node child in n.nodes) {
          walk(child);
        }
        if (block) sb.write('\n');
        return;
      }
      for (final dom.Node child in n.nodes) {
        walk(child);
      }
    }

    walk(node);
    return sb.toString();
  }

  // ------------------------------------------------------------------ JSON

  Future<List<dynamic>> _evalJson(String rule, RuleContext ctx) async {
    String r = rule.trim();
    if (r.toLowerCase().startsWith('@json:')) r = r.substring(6).trim();

    dynamic root = ctx.node;
    if (root is String) {
      try {
        root = jsonDecode(root);
      } catch (_) {
        return const <dynamic>[];
      }
    }
    if (root is! Map && root is! List) return const <dynamic>[];
    if (r.isEmpty || r == r'$') return <dynamic>[root];
    return _jsonPath(root, r);
  }

  List<dynamic> _jsonPath(dynamic root, String path) {
    String p = path.trim();
    if (p.startsWith(r'$')) p = p.substring(1);
    List<dynamic> cur = <dynamic>[root];
    int i = 0;
    final RegExp nameRe = RegExp(r'^[^\.\[\]]+');

    while (i < p.length) {
      if (p.startsWith('..', i)) {
        i += 2;
        final RegExpMatch? m = nameRe.firstMatch(p.substring(i));
        if (m == null) break;
        final String key = m.group(0)!;
        i += key.length;
        cur = cur
            .expand((dynamic n) => _jsonDescendants(n, key))
            .toList();
        continue;
      }
      if (p[i] == '.') {
        i++;
        final RegExpMatch? m = nameRe.firstMatch(p.substring(i));
        if (m == null) break;
        final String key = m.group(0)!;
        i += key.length;
        cur = cur.expand((dynamic n) => _jsonChild(n, key)).toList();
        continue;
      }
      if (p[i] == '[') {
        final int end = p.indexOf(']', i);
        if (end < 0) break;
        final String inner = p.substring(i + 1, end).trim();
        i = end + 1;
        if (inner == '*') {
          cur = cur.expand(_jsonChildren).toList();
        } else if (inner.startsWith("'") || inner.startsWith('"')) {
          final String key = inner.substring(1, inner.length - 1);
          cur = cur.expand((dynamic n) => _jsonChild(n, key)).toList();
        } else if (inner.startsWith('?')) {
          // 不支持过滤表达式，跳过
          continue;
        } else {
          final int? n = int.tryParse(inner);
          if (n == null) break;
          final List<dynamic> next = <dynamic>[];
          for (final dynamic c in cur) {
            final List<dynamic> list = _jsonChildren(c);
            final int idx = n < 0 ? list.length + n : n;
            if (idx >= 0 && idx < list.length) next.add(list[idx]);
          }
          cur = next;
        }
        continue;
      }
      final RegExpMatch? m = nameRe.firstMatch(p.substring(i));
      if (m == null) break;
      final String key = m.group(0)!;
      i += key.length;
      cur = cur.expand((dynamic n) => _jsonChild(n, key)).toList();
    }
    return cur;
  }

  List<dynamic> _jsonChild(dynamic node, String key) {
    if (node is Map) {
      if (node.containsKey(key)) return <dynamic>[node[key]];
      return const <dynamic>[];
    }
    if (node is List) {
      final int? n = int.tryParse(key);
      if (n != null && n >= 0 && n < node.length) return <dynamic>[node[n]];
      return node
          .expand((dynamic e) => _jsonChild(e, key))
          .toList();
    }
    return const <dynamic>[];
  }

  List<dynamic> _jsonChildren(dynamic node) {
    if (node is List) return List<dynamic>.from(node);
    if (node is Map) return node.values.toList();
    return const <dynamic>[];
  }

  List<dynamic> _jsonDescendants(dynamic node, String key) {
    final List<dynamic> out = <dynamic>[];
    void walk(dynamic n) {
      if (n is Map) {
        n.forEach((dynamic k, dynamic v) {
          if (k.toString() == key) out.add(v);
          walk(v);
        });
      } else if (n is List) {
        for (final dynamic e in n) {
          walk(e);
        }
      }
    }

    walk(node);
    return out;
  }

  // ---------------------------------------------------------------- XPath

  Future<List<dynamic>> _evalXPath(String rule, RuleContext ctx) async {
    String r = rule.trim();
    if (r.toLowerCase().startsWith('@xpath:')) r = r.substring(7).trim();
    if (r.isEmpty) return const <dynamic>[];

    dom.Node root;
    final dynamic node = ctx.node;
    if (node is dom.Node) {
      root = node;
    } else {
      try {
        root = html_parser.parse(ctx.text);
      } catch (_) {
        return const <dynamic>[];
      }
    }

    try {
      return XPathEngine.evaluate(root, r);
    } catch (_) {
      return const <dynamic>[];
    }
  }

  // ---------------------------------------------------------------- Regex

  Future<List<dynamic>> _evalRegex(String pattern, RuleContext ctx) async {
    RegExp re;
    try {
      re = RegExp(pattern, multiLine: true, dotAll: true);
    } catch (e) {
      throw RuleException('正则表达式非法：$pattern', detail: e.toString());
    }
    final String input = ctx.text;
    final List<dynamic> out = <dynamic>[];
    for (final RegExpMatch m in re.allMatches(input)) {
      String v;
      if (m.groupCount >= 1 && m.group(1) != null) {
        v = m.group(1)!;
      } else {
        v = m.group(0) ?? '';
      }
      v = v.trim();
      if (v.isNotEmpty) out.add(v);
    }
    return out;
  }

  // ------------------------------------------------------------------- JS

  Future<List<dynamic>> _evalJs(String code, RuleContext ctx) async {
    final JsEngine? engine = js;
    if (engine == null) {
      throw RuleException('未启用 JS 引擎，无法执行规则：$code');
    }
    return engine.run(
      code,
      result: ctx.text,
      baseUrl: ctx.baseUrl,
      sourceUrl: ctx.sourceUrl,
      sourceName: ctx.sourceName,
      headers: ctx.headers,
    );
  }

  // -------------------------------------------------------------- utilities

  String _asText(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    if (v is dom.Element) return TextUtil.squeeze(_innerText(v));
    if (v is dom.Node) return TextUtil.squeeze(v.text ?? '');
    if (v is num || v is bool) return v.toString();
    try {
      return jsonEncode(v);
    } catch (_) {
      return v.toString();
    }
  }

  String _applyReplace(String input, String pattern, String replacement) {
    RegExp re;
    try {
      re = RegExp(pattern, multiLine: true, dotAll: true);
    } catch (_) {
      return input;
    }
    return input.replaceAllMapped(re, (Match m) => _expand(replacement, m));
  }

  String _expand(String tpl, Match m) {
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < tpl.length; i++) {
      final String c = tpl[i];
      if (c == r'$' && i + 1 < tpl.length) {
        final String next = tpl[i + 1];
        if (next == r'$') {
          sb.write(r'$');
          i++;
          continue;
        }
        if (next == '&') {
          sb.write(m.group(0) ?? '');
          i++;
          continue;
        }
        final int? d = int.tryParse(next);
        if (d != null) {
          if (d <= m.groupCount) sb.write(m.group(d) ?? '');
          i++;
          continue;
        }
      }
      if (c == r'\' && i + 1 < tpl.length) {
        final String next = tpl[i + 1];
        if (next == 'n') {
          sb.write('\n');
          i++;
          continue;
        }
        if (next == 't') {
          sb.write('\t');
          i++;
          continue;
        }
        sb.write(next);
        i++;
        continue;
      }
      sb.write(c);
    }
    return sb.toString();
  }

  /// 按顶层运算符切分，跳过 `{{ }}` 与引号内的内容。
  static List<String> _splitLogical(String input) {
    final List<String> parts = <String>[];
    final StringBuffer buf = StringBuffer();
    int i = 0;
    int depth = 0;
    while (i < input.length) {
      if (input.startsWith('{{', i)) {
        depth++;
        buf.write('{{');
        i += 2;
        continue;
      }
      if (input.startsWith('}}', i) && depth > 0) {
        depth--;
        buf.write('}}');
        i += 2;
        continue;
      }
      if (depth == 0 &&
          (input.startsWith('&&', i) || input.startsWith('||', i))) {
        parts.add(buf.toString());
        buf.clear();
        parts.add(input.substring(i, i + 2));
        i += 2;
        continue;
      }
      if (input[i] == r'\' && i + 1 < input.length) {
        buf.write(input[i]);
        buf.write(input[i + 1]);
        i += 2;
        continue;
      }
      buf.write(input[i]);
      i++;
    }
    parts.add(buf.toString());
    return parts;
  }

  /// 按顶层分隔符切分，跳过 `{{ }}` 与引号内的内容。
  static List<String> _splitTop(String input, String sep) {
    final List<String> parts = <String>[];
    final StringBuffer buf = StringBuffer();
    int i = 0;
    int depth = 0;
    String? quote;
    while (i < input.length) {
      final String ch = input[i];
      if (quote != null) {
        buf.write(ch);
        if (ch == r'\' && i + 1 < input.length) {
          buf.write(input[i + 1]);
          i += 2;
          continue;
        }
        if (ch == quote) quote = null;
        i++;
        continue;
      }
      if (input.startsWith('{{', i)) {
        depth++;
        buf.write('{{');
        i += 2;
        continue;
      }
      if (input.startsWith('}}', i) && depth > 0) {
        depth--;
        buf.write('}}');
        i += 2;
        continue;
      }
      if (depth == 0 && (ch == '"' || ch == "'")) {
        quote = ch;
        buf.write(ch);
        i++;
        continue;
      }
      if (depth == 0 && input.startsWith(sep, i)) {
        parts.add(buf.toString());
        buf.clear();
        i += sep.length;
        continue;
      }
      if (ch == r'\' && i + 1 < input.length) {
        buf.write(ch);
        buf.write(input[i + 1]);
        i += 2;
        continue;
      }
      buf.write(ch);
      i++;
    }
    parts.add(buf.toString());
    return parts;
  }

  /// 套用 `!start:end` / `!n` 切片（end 不含，负数从末尾算）。
  List<dom.Element> _applySlice(List<dom.Element> els, _Slice slice) {
    final int len = els.length;
    int start = slice.start;
    if (start < 0) start += len;
    if (slice.single) {
      if (start < 0 || start >= len) return const <dom.Element>[];
      return <dom.Element>[els[start]];
    }
    int end = slice.end ?? len;
    if (end < 0) end += len;
    if (end > len) end = len;
    if (start < 0) start = 0;
    if (start >= end) return const <dom.Element>[];
    return els.sublist(start, end);
  }
}

/// `!start:end` 切片描述。
class _Slice {
  const _Slice(this.start, this.end, {this.single = false});

  final int start;
  final int? end;
  final bool single;
}

/// CSS 属性运算符过滤（`[href*="/catalog"]` 之类），因为 package:html
/// 的 querySelector 只支持 `[attr]` 与 `[attr=value]`。
class _AttrFilter {
  const _AttrFilter(this.attr, this.op, this.value);

  final String attr;
  final String op;
  final String value;

  bool match(dom.Element e) {
    final String v = e.attributes[attr] ?? '';
    switch (op) {
      case '*=':
        return v.contains(value);
      case '^=':
        return v.startsWith(value);
      case r'$=':
        return v.endsWith(value);
      case '~=':
        return v.split(RegExp(r'\s+')).contains(value);
      case '|=':
        return v == value || v.startsWith('$value-');
    }
    return false;
  }
}
