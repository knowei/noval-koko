import 'package:html/dom.dart' as dom;

/// 一个够用的 XPath 1.0 子集，直接跑在 `package:html` 的 DOM 上。
///
/// 书源里的 XPath 绝大多数都是这几种形态，支持它们即可覆盖真实数据：
/// * `/html/body/div[2]/p`     绝对路径 + 下标
/// * `//div[@class='content']`  任意层级 + 属性过滤
/// * `//a[contains(@href,'/book/')]`
/// * `//div[@id='x']//text()`   取文本
/// * `//img/@src`               取属性
/// * `//*[@class='a']`, `.//p`
class XPathEngine {
  const XPathEngine._();

  /// 求值。返回 [dom.Element] 列表、字符串列表（`text()` / `@attr`），或空列表。
  static List<dynamic> evaluate(dom.Node root, String expr) {
    String path = expr.trim();
    if (path.isEmpty) return const <dynamic>[];

    // 尾部取值：/text() 或 /@attr
    String? extractText;
    String? extractAttr;
    final RegExpMatch? mText = RegExp(r'/\s*text\(\)\s*$').firstMatch(path);
    if (mText != null) {
      extractText = 'text';
      path = path.substring(0, mText.start);
    } else {
      final RegExpMatch? mAttr = RegExp(r'/\s*@([\w:-]+)\s*$').firstMatch(path);
      if (mAttr != null) {
        extractAttr = mAttr.group(1);
        path = path.substring(0, mAttr.start);
      }
    }
    if (path.isEmpty || path == '.') {
      path = '.';
    }

    final List<_Step>? steps = _parse(path);
    if (steps == null) return const <dynamic>[];

    List<dom.Node> current = <dom.Node>[root];
    for (final _Step step in steps) {
      current = _apply(current, step);
      if (current.isEmpty) return const <dynamic>[];
    }

    if (extractText != null) {
      final List<dynamic> out = <dynamic>[];
      for (final dom.Node n in current) {
        final String t = _textOf(n).trim();
        if (t.isNotEmpty) out.add(t);
      }
      return out;
    }
    if (extractAttr != null) {
      final List<dynamic> out = <dynamic>[];
      for (final dom.Node n in current) {
        if (n is dom.Element) {
          final String? v = n.attributes[extractAttr];
          if (v != null && v.trim().isNotEmpty) out.add(v.trim());
        }
      }
      return out;
    }
    return current;
  }

  // ------------------------------------------------------------------ 解析

  static List<_Step>? _parse(String path) {
    final List<_Step> steps = <_Step>[];
    int i = 0;
    bool descendant = false;

    if (path.startsWith('//')) {
      descendant = true;
      i = 2;
    } else if (path.startsWith('/')) {
      i = 1;
    }

    while (i < path.length) {
      final int end = _nextSeparator(path, i);
      final String raw = path.substring(i, end).trim();
      i = end;
      if (raw.isEmpty) {
        if (i < path.length && path[i] == '/') {
          descendant = true;
          i++;
        }
        continue;
      }

      final _Step? step = _parseStep(raw, descendant);
      if (step == null) return null;
      steps.add(step);

      descendant = false;
      if (i < path.length && path[i] == '/') {
        if (i + 1 < path.length && path[i + 1] == '/') {
          descendant = true;
          i += 2;
        } else {
          i++;
        }
      }
    }
    if (steps.isEmpty) return null;
    return steps;
  }

  /// 找到下一个「顶层」的 `/`（跳过 `[]` 与引号内的内容）。
  static int _nextSeparator(String s, int start) {
    int depth = 0;
    String? quote;
    for (int i = start; i < s.length; i++) {
      final String c = s[i];
      if (quote != null) {
        if (c == quote) quote = null;
        continue;
      }
      if (c == '"' || c == "'") {
        quote = c;
        continue;
      }
      if (c == '[') depth++;
      if (c == ']') depth--;
      if (c == '/' && depth == 0) return i;
    }
    return s.length;
  }

  static _Step? _parseStep(String raw, bool descendant) {
    String s = raw.trim();
    String axis;
    if (s.startsWith('..')) {
      return _Step(axis: 'parent', name: '*', predicates: const <String>[]);
    }
    if (s == '.') {
      return _Step(axis: 'self', name: '*', predicates: const <String>[]);
    }
    if (s.startsWith('.')) s = s.substring(1);

    // 取出谓词
    final List<String> predicates = <String>[];
    final int bracket = s.indexOf('[');
    String name = bracket < 0 ? s : s.substring(0, bracket);
    if (bracket >= 0) {
      int i = bracket;
      while (i < s.length) {
        if (s[i] == '[') {
          int depth = 0;
          String? quote;
          int j = i;
          for (; j < s.length; j++) {
            final String c = s[j];
            if (quote != null) {
              if (c == quote) quote = null;
              continue;
            }
            if (c == '"' || c == "'") {
              quote = c;
              continue;
            }
            if (c == '[') depth++;
            if (c == ']') {
              depth--;
              if (depth == 0) {
                predicates.add(s.substring(i + 1, j));
                i = j + 1;
                break;
              }
            }
          }
          if (j >= s.length) break;
          continue;
        }
        i++;
      }
    }

    name = name.trim();
    if (name.isEmpty) return null;

    axis = descendant ? 'descendant' : 'child';
    if (name.startsWith('@')) {
      axis = 'attribute';
      name = name.substring(1);
    } else if (name == 'text()') {
      axis = 'text';
      name = '*';
    } else if (name == 'node()' || name == '*') {
      name = '*';
    } else if (name.startsWith('following-sibling::')) {
      axis = 'following-sibling';
      name = name.substring('following-sibling::'.length);
    } else if (name.startsWith('preceding-sibling::')) {
      axis = 'preceding-sibling';
      name = name.substring('preceding-sibling::'.length);
    }
    return _Step(axis: axis, name: name, predicates: predicates);
  }

  // ------------------------------------------------------------------ 求值

  static List<dom.Node> _apply(List<dom.Node> ctx, _Step step) {
    final List<dom.Node> out = <dom.Node>[];

    for (final dom.Node node in ctx) {
      List<dom.Node> candidates;
      switch (step.axis) {
        case 'self':
          candidates = <dom.Node>[node];
        case 'parent':
          candidates = node.parent == null
              ? const <dom.Node>[]
              : <dom.Node>[node.parent!];
        case 'descendant':
          candidates = _descendants(node).whereType<dom.Element>().toList();
        case 'text':
          candidates = <dom.Node>[];
          for (final dom.Node d in _descendants(node)) {
            if (d is dom.Text && d.data.trim().isNotEmpty) candidates.add(d);
          }
        case 'attribute':
          final List<dom.Node> attrs = <dom.Node>[];
          for (final dom.Node d in _descendants(node)) {
            if (d is dom.Element) {
              final String? v = d.attributes[step.name];
              if (v != null && v.trim().isNotEmpty) attrs.add(dom.Text(v));
            }
          }
          candidates = attrs;
        case 'following-sibling':
          candidates = _siblings(node, step.name, forward: true);
        case 'preceding-sibling':
          candidates = _siblings(node, step.name, forward: false);
        default:
          candidates =
              node.nodes.whereType<dom.Element>().toList(growable: false);
      }

      if (step.name != '*' &&
          step.axis != 'attribute' &&
          step.axis != 'text' &&
          step.axis != 'parent' &&
          step.axis != 'self') {
        candidates = candidates
            .where((dom.Node n) =>
                n is dom.Element &&
                (n.localName ?? '').toLowerCase() == step.name.toLowerCase())
            .toList();
      }

      List<dom.Node> filtered = candidates;
      for (final String predicate in step.predicates) {
        filtered = _applyPredicate(filtered, predicate);
      }
      out.addAll(filtered);
    }
    return out;
  }

  static List<dom.Node> _descendants(dom.Node node) {
    final List<dom.Node> out = <dom.Node>[];
    void walk(dom.Node n) {
      for (final dom.Node child in n.nodes) {
        out.add(child);
        walk(child);
      }
    }

    walk(node);
    return out;
  }

  static List<dom.Node> _siblings(dom.Node node, String name,
      {required bool forward}) {
    final dom.Node? parent = node.parent;
    if (parent == null) return const <dom.Node>[];
    final List<dom.Element> siblings =
        parent.nodes.whereType<dom.Element>().toList(growable: false);
    final int idx = siblings.indexOf(node as dom.Element);
    if (idx < 0) return const <dom.Node>[];
    final List<dom.Element> slice = <dom.Element>[];
    if (forward) {
      slice.addAll(siblings.skip(idx + 1));
    } else {
      slice.addAll(siblings.take(idx).toList().reversed);
    }
    return slice
        .where((dom.Element e) =>
            name == '*' || (e.localName ?? '').toLowerCase() == name.toLowerCase())
        .toList();
  }

  static List<dom.Node> _applyPredicate(List<dom.Node> nodes, String raw) {
    final String p = raw.trim();
    if (p.isEmpty) return nodes;

    final int? index = int.tryParse(p);
    if (index != null) {
      if (index >= 1 && index <= nodes.length) {
        return <dom.Node>[nodes[index - 1]];
      }
      return const <dom.Node>[];
    }
    if (p == 'last()') {
      return nodes.isEmpty ? const <dom.Node>[] : <dom.Node>[nodes.last];
    }
    if (p.startsWith('not(') && p.endsWith(')')) {
      final String inner = p.substring(4, p.length - 1);
      final Set<dom.Node> rejected = _applyPredicate(nodes, inner).toSet();
      return nodes.where((dom.Node n) => !rejected.contains(n)).toList();
    }

    return nodes.where((dom.Node n) => _test(n, p)).toList();
  }

  /// 判断单个节点是否满足谓词表达式（支持 and / or 组合）。
  static bool _test(dom.Node node, String expr) {
    final String e = expr.trim();
    if (e.isEmpty) return true;

    final List<String> orParts = _splitOp(e, ' or ');
    if (orParts.length > 1) {
      return orParts.any((String part) => _test(node, part));
    }
    final List<String> andParts = _splitOp(e, ' and ');
    if (andParts.length > 1) {
      return andParts.every((String part) => _test(node, part));
    }

    if (e.startsWith('not(') && e.endsWith(')')) {
      return !_test(node, e.substring(4, e.length - 1));
    }

    // contains(x, 'y')
    final RegExpMatch? mc = RegExp(
            r'''^contains\(\s*(.+?)\s*,\s*(['"])(.*?)\2\s*\)$''')
        .firstMatch(e);
    if (mc != null) {
      final String left = _valueOf(node, mc.group(1)!);
      return left.contains(mc.group(3)!);
    }

    // 布尔属性存在性：@href
    final RegExpMatch? ma = RegExp(r'^@([\w:-]+)$').firstMatch(e);
    if (ma != null) {
      if (node is dom.Element) return node.attributes.containsKey(ma.group(1));
      return false;
    }

    // 比较： @x = 'v' / text() = 'v' / string(.) = 'v'
    final RegExpMatch? mcmp = RegExp(
            r'''^(.+?)\s*(=|!=)\s*(['"])(.*?)\3$''')
        .firstMatch(e);
    if (mcmp != null) {
      final String left = _valueOf(node, mcmp.group(1)!).trim();
      final String right = mcmp.group(4)!;
      return mcmp.group(2) == '=' ? left == right : left != right;
    }

    return _valueOf(node, e).trim().isNotEmpty;
  }

  static List<String> _splitOp(String e, String op) {
    final List<String> parts = <String>[];
    String? quote;
    int start = 0;
    for (int i = 0; i < e.length; i++) {
      final String c = e[i];
      if (quote != null) {
        if (c == quote) quote = null;
        continue;
      }
      if (c == '"' || c == "'") {
        quote = c;
        continue;
      }
      if (e.startsWith(op, i)) {
        parts.add(e.substring(start, i));
        start = i + op.length;
        i += op.length - 1;
      }
    }
    if (parts.isEmpty) return <String>[e];
    parts.add(e.substring(start));
    return parts;
  }

  static String _valueOf(dom.Node node, String expr) {
    final String e = expr.trim();
    if (e.startsWith('@')) {
      final String name = e.substring(1);
      if (node is dom.Element) return node.attributes[name] ?? '';
      return '';
    }
    if (e == 'text()' || e == '.' || e == 'string(.)') return _textOf(node);
    if (e == 'position()' || e == 'last()') return '';
    return _textOf(node);
  }

  static String _textOf(dom.Node node) {
    if (node is dom.Text) return node.data;
    return node.text ?? '';
  }
}

class _Step {
  const _Step({
    required this.axis,
    required this.name,
    required this.predicates,
  });

  final String axis; // child | descendant | self | parent | text | attribute | following-sibling | preceding-sibling
  final String name;
  final List<String> predicates;
}
