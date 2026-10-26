/// 在 QuickJS 里模拟 `org.jsoup.Jsoup` / `Elements` / `Element`。
///
/// 真实 Legado 书源里非常常见这种规则：
///
/// ```js
/// <js>org.jsoup.Jsoup.parse(result).select('.book_other li').text()</js>
/// ```
///
/// 这里解析的是**已经在 JS 内存里的字符串**，不涉及网络，所以可以用纯 JS
/// 实现一个迷你 DOM + CSS 选择器子集，不必走异步桥。`java.ajax()` 仍然走桥。
class JsoupShim {
  const JsoupShim._();

  static const String source = r'''
var org = (function () {
  var VOID = {area:1,base:1,br:1,col:1,embed:1,hr:1,img:1,input:1,link:1,meta:1,param:1,source:1,track:1,wbr:1};
  var RAW = {script:1,style:1,textarea:1,title:1,noscript:1};

  function ent(s) {
    if (!s || s.indexOf('&') < 0) return s;
    return s.replace(/&(#x?[0-9a-fA-F]+|[a-zA-Z]+);/g, function (m, e) {
      if (e.charAt(0) === '#') {
        var code = (e.charAt(1) === 'x' || e.charAt(1) === 'X')
          ? parseInt(e.substring(2), 16) : parseInt(e.substring(1), 10);
        if (!isNaN(code) && code > 0) {
          try { return String.fromCharCode(code); } catch (x) { return m; }
        }
        return m;
      }
      var map = {
        amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ',
        ensp: ' ', emsp: ' ', middot: '·', mdash: '—', ndash: '–',
        hellip: '…', ldquo: '“', rdquo: '”', lsquo: '‘', rsquo: '’',
        copy: '©', reg: '®', trade: '™', times: '×', divide: '÷'
      };
      return Object.prototype.hasOwnProperty.call(map, e) ? map[e] : m;
    });
  }

  function norm(s) {
    return String(s === undefined || s === null ? '' : s)
      .replace(/[\s\u00a0\u3000]+/g, ' ')
      .replace(/^ | $/g, '');
  }

  function esc(s) {
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  var P = {};

  P.tagName = function () { return this.tag; };
  P.nodeName = function () { return this.tag; };
  P.id = function () { return this.attrs.id || ''; };
  P.className = function () { return this.attrs['class'] || ''; };
  P.hasAttr = function (k) {
    return Object.prototype.hasOwnProperty.call(this.attrs, String(k).toLowerCase());
  };
  P.attr = function (k, v) {
    var key = String(k === undefined ? '' : k).toLowerCase();
    if (key.indexOf('abs:') === 0) {
      var real = this.attrs[key.substring(4)];
      return real === undefined ? '' : __novalAbs(real);
    }
    if (v !== undefined) {
      this.attrs[key] = String(v);
      return this;
    }
    var val = this.attrs[key];
    return val === undefined ? '' : val;
  };
  P.removeAttr = function (k) { delete this.attrs[String(k).toLowerCase()]; return this; };
  P.text = function () {
    return norm(collectText(this, []).join(' '));
  };
  P.ownText = function () {
    var out = [];
    for (var i = 0; i < this.kids.length; i++) {
      if (this.kids[i].tag === '#text') out.push(this.kids[i].text);
    }
    return norm(out.join(' '));
  };
  P.html = function () { return innerOf(this); };
  P.innerHtml = function () { return innerOf(this); };
  P.outerHtml = function () { return outerOf(this); };
  P.toString = function () { return outerOf(this); };
  P.select = function (sel) { return new Elements(selectAll([this], sel)); };
  P.children = function () { return new Elements(elementsOf(this)); };
  P.child = function (i) { var els = elementsOf(this); return els[i] || null; };
  P.childNodeSize = function () { return this.kids.length; };
  P.parent = function () { return this.parent && this.parent.tag !== '#root' ? this.parent : null; };
  P.parents = function () {
    var out = [], p = this.parent;
    while (p && p.tag !== '#root') { out.push(p); p = p.parent; }
    return new Elements(out);
  };
  P.next = function () { return sibling(this, 1); };
  P.prev = function () { return sibling(this, -1); };
  P.nextElementSibling = function () { return sibling(this, 1); };
  P.previousElementSibling = function () { return sibling(this, -1); };
  P.siblings = function () {
    if (!this.parent) return new Elements([]);
    return new Elements(elementsOf(this.parent).filter(function (e) { return e !== this; }, this));
  };
  P.body = function () { return firstTag(this, 'body') || this; };
  P.head = function () { return firstTag(this, 'head') || this; };
  P.getAllElements = function () { return new Elements([this].concat(descendantsOf(this))); };
  P.eachText = function () { return [this.text()]; };

  function sibling(node, dir) {
    if (!node.parent) return null;
    var els = elementsOf(node.parent);
    var i = els.indexOf(node);
    if (i < 0) return null;
    var j = i + dir;
    return j >= 0 && j < els.length ? els[j] : null;
  }

  function firstTag(node, tag) {
    var all = descendantsOf(node);
    for (var i = 0; i < all.length; i++) if (all[i].tag === tag) return all[i];
    return null;
  }

  function mk(tag, attrs, parent) {
    var n = { tag: tag, attrs: attrs || {}, kids: [], parent: parent || null };
    for (var k in P) {
      if (Object.prototype.hasOwnProperty.call(P, k)) n[k] = P[k];
    }
    return n;
  }

  function collectText(node, out) {
    for (var i = 0; i < node.kids.length; i++) {
      var k = node.kids[i];
      if (k.tag === '#text') out.push(k.text);
      else if (k.tag !== 'script' && k.tag !== 'style') collectText(k, out);
    }
    return out;
  }

  function innerOf(node) {
    var out = '';
    for (var i = 0; i < node.kids.length; i++) out += outerOf(node.kids[i]);
    return out;
  }

  function outerOf(node) {
    if (!node) return '';
    if (node.tag === '#text') return esc(node.text);
    if (node.tag === '#root') return innerOf(node);
    var s = '<' + node.tag;
    for (var k in node.attrs) {
      if (!Object.prototype.hasOwnProperty.call(node.attrs, k)) continue;
      s += ' ' + k + '="' + String(node.attrs[k]).replace(/"/g, '&quot;') + '"';
    }
    s += '>';
    if (VOID[node.tag]) return s;
    return s + innerOf(node) + '</' + node.tag + '>';
  }

  function elementsOf(node) {
    var out = [];
    for (var i = 0; i < node.kids.length; i++) {
      if (node.kids[i].tag !== '#text') out.push(node.kids[i]);
    }
    return out;
  }

  function descendantsOf(node) {
    var out = [];
    (function walk(n) {
      for (var i = 0; i < n.kids.length; i++) {
        var k = n.kids[i];
        if (k.tag === '#text') continue;
        out.push(k);
        walk(k);
      }
    })(node);
    return out;
  }

  function findGt(html, from) {
    var q = 0;
    for (var i = from + 1; i < html.length; i++) {
      var c = html.charAt(i);
      if (q) { if (c === q) q = 0; continue; }
      if (c === '"' || c === "'") { q = c; continue; }
      if (c === '>') return i;
    }
    return -1;
  }

  function parseAttrs(s) {
    var out = {};
    if (!s) return out;
    var re = /([^\s=\/>]+)(?:\s*=\s*("([^"]*)"|'([^']*)'|([^\s>]*)))?/g;
    var m;
    while ((m = re.exec(s))) {
      var k = m[1].toLowerCase();
      if (k === '' || k.charAt(0) === '/' || k.charAt(0) === '"') continue;
      var v = m[3] !== undefined ? m[3] : (m[4] !== undefined ? m[4] : (m[5] !== undefined ? m[5] : ''));
      out[k] = ent(v);
    }
    return out;
  }

  function addText(parent, s, raw) {
    if (!s) return;
    parent.kids.push({ tag: '#text', text: raw ? s : ent(s), attrs: {}, kids: [], parent: parent });
  }

  function parseHtml(html) {
    html = String(html === undefined || html === null ? '' : html);
    var root = mk('#root', {}, null);
    var stack = [root];
    var i = 0;
    var n = html.length;
    var lower = html.toLowerCase();
    while (i < n) {
      var lt = html.indexOf('<', i);
      if (lt < 0) { addText(stack[stack.length - 1], html.substring(i)); break; }
      if (lt > i) addText(stack[stack.length - 1], html.substring(i, lt));
      if (html.substr(lt, 4) === '<!--') {
        var endc = html.indexOf('-->', lt + 4);
        i = endc < 0 ? n : endc + 3;
        continue;
      }
      if (html.substr(lt, 2) === '<!' || html.substr(lt, 2) === '<?') {
        var e2 = html.indexOf('>', lt);
        i = e2 < 0 ? n : e2 + 1;
        continue;
      }
      if (html.substr(lt, 2) === '</') {
        var e3 = html.indexOf('>', lt);
        if (e3 < 0) break;
        var cname = html.substring(lt + 2, e3).trim().toLowerCase();
        for (var s = stack.length - 1; s > 0; s--) {
          if (stack[s].tag === cname) { stack.length = s; break; }
        }
        i = e3 + 1;
        continue;
      }
      var gt = findGt(html, lt);
      if (gt < 0) { addText(stack[stack.length - 1], html.substring(lt)); break; }
      var raw = html.substring(lt + 1, gt);
      i = gt + 1;
      var selfClose = raw.charAt(raw.length - 1) === '/';
      if (selfClose) raw = raw.substring(0, raw.length - 1);
      var m2 = /^([a-zA-Z][^\s\/>]*)\s*([\s\S]*)$/.exec(raw);
      if (!m2) continue;
      var tag = m2[1].toLowerCase();
      var el = mk(tag, parseAttrs(m2[2]), stack[stack.length - 1]);
      stack[stack.length - 1].kids.push(el);
      if (VOID[tag] || selfClose) continue;
      if (RAW[tag]) {
        var close = lower.indexOf('</' + tag, i);
        var body = close < 0 ? html.substring(i) : html.substring(i, close);
        if (body) addText(el, body, true);
        if (close < 0) { i = n; } else {
          var gt2 = html.indexOf('>', close);
          i = gt2 < 0 ? n : gt2 + 1;
        }
        continue;
      }
      stack.push(el);
    }
    return root;
  }

  function splitTop(s, sep) {
    var out = [];
    var depth = 0;
    var q = 0;
    var buf = '';
    for (var i = 0; i < s.length; i++) {
      var c = s.charAt(i);
      if (q) { buf += c; if (c === q) q = 0; continue; }
      if (c === '"' || c === "'") { q = c; buf += c; continue; }
      if (c === '(' || c === '[') { depth++; buf += c; continue; }
      if (c === ')' || c === ']') { depth--; buf += c; continue; }
      if (depth === 0 && c === sep) { out.push(buf); buf = ''; continue; }
      buf += c;
    }
    out.push(buf);
    return out;
  }

  function parseSimple(s) {
    var o = { tag: '', id: '', cls: [], attrs: [], pseudo: [] };
    var i = 0;
    var m = /^([a-zA-Z][\w-]*|\*)/.exec(s);
    if (m) {
      o.tag = m[1] === '*' ? '' : m[1].toLowerCase();
      i = m[1].length;
    }
    while (i < s.length) {
      var c = s.charAt(i);
      var rest = s.substring(i);
      var mm;
      if (c === '.') {
        mm = /^\.([\w-]+)/.exec(rest);
        if (mm) { o.cls.push(mm[1]); i += mm[0].length; continue; }
      } else if (c === '#') {
        mm = /^#([\w-]+)/.exec(rest);
        if (mm) { o.id = mm[1]; i += mm[0].length; continue; }
      } else if (c === '[') {
        var close = s.indexOf(']', i);
        if (close > 0) {
          var body = s.substring(i + 1, close).trim();
          var am = /^([\w:.\-]+)\s*(?:([\^$*!~]?=)\s*(?:"([^"]*)"|'([^']*)'|([^\]]*)))?$/.exec(body);
          if (am) {
            o.attrs.push({
              name: am[1].toLowerCase(),
              op: am[2] || '',
              val: am[3] !== undefined ? am[3]
                : (am[4] !== undefined ? am[4] : (am[5] !== undefined ? am[5] : ''))
            });
          }
          i = close + 1;
          continue;
        }
        break;
      } else if (c === ':') {
        mm = /^:([\w-]+)(?:\(([^)]*)\))?/.exec(rest);
        if (mm) {
          o.pseudo.push({ name: mm[1].toLowerCase(), arg: mm[2] });
          i += mm[0].length;
          continue;
        }
      }
      i++;
    }
    return o;
  }

  function hasClass(node, cls) {
    var raw = node.attrs['class'];
    if (!raw) return false;
    var parts = String(raw).split(/\s+/);
    for (var i = 0; i < parts.length; i++) if (parts[i] === cls) return true;
    return false;
  }

  function matchSimple(node, o) {
    if (o.tag && node.tag !== o.tag) return false;
    if (o.id && node.attrs.id !== o.id) return false;
    for (var i = 0; i < o.cls.length; i++) if (!hasClass(node, o.cls[i])) return false;
    for (var j = 0; j < o.attrs.length; j++) {
      var a = o.attrs[j];
      var v = node.attrs[a.name];
      var has = v !== undefined;
      if (a.name.indexOf('abs:') === 0) {
        has = node.attrs[a.name.substring(4)] !== undefined;
        v = has ? __novalAbs(node.attrs[a.name.substring(4)]) : undefined;
      }
      switch (a.op) {
        case '':
          if (!has) return false;
          break;
        case '!=':
          if (has && String(v) === a.val) return false;
          break;
        case '=':
          if (!has || String(v) !== a.val) return false;
          break;
        case '^=':
          if (!has || String(v).indexOf(a.val) !== 0) return false;
          break;
        case '$=':
          if (!has || String(v).lastIndexOf(a.val) !== String(v).length - a.val.length) return false;
          break;
        case '*=':
          if (!has || String(v).indexOf(a.val) < 0) return false;
          break;
        case '~=':
          if (!has || (' ' + String(v) + ' ').indexOf(' ' + a.val + ' ') < 0) return false;
          break;
        default:
          if (!has) return false;
      }
    }
    return true;
  }

  function applyPseudo(list, pseudo) {
    var out = list;
    for (var i = 0; i < pseudo.length; i++) {
      var p = pseudo[i];
      if (p.name === 'first') out = out.length ? [out[0]] : [];
      else if (p.name === 'last') out = out.length ? [out[out.length - 1]] : [];
      else if (p.name === 'eq') {
        var idx = parseInt(p.arg, 10);
        if (isNaN(idx)) idx = 0;
        if (idx < 0) idx += out.length;
        out = idx >= 0 && idx < out.length ? [out[idx]] : [];
      } else if (p.name === 'contains') {
        var needle = String(p.arg || '').replace(/^["']|["']$/g, '');
        var filtered = [];
        for (var k = 0; k < out.length; k++) {
          if (out[k].text().indexOf(needle) >= 0) filtered.push(out[k]);
        }
        out = filtered;
      } else if (p.name === 'not') {
        var inner = parseSimple(String(p.arg || ''));
        var keep = [];
        for (var q2 = 0; q2 < out.length; q2++) {
          if (!matchSimple(out[q2], inner)) keep.push(out[q2]);
        }
        out = keep;
      }
    }
    return out;
  }

  function selectAll(scopeList, selector) {
    var out = [];
    var groups = splitTop(String(selector === undefined ? '' : selector), ',');
    for (var gi = 0; gi < groups.length; gi++) {
      var g = groups[gi].trim();
      if (g === '') continue;
      var toks = g.replace(/\s*>\s*/g, ' > ').split(/\s+/);
      var cur = scopeList.slice();
      var childOnly = false;
      for (var ti = 0; ti < toks.length; ti++) {
        var t = toks[ti];
        if (t === '') continue;
        if (t === '>') { childOnly = true; continue; }
        var simple = parseSimple(t);
        var next = [];
        for (var ci = 0; ci < cur.length; ci++) {
          var pool = childOnly ? elementsOf(cur[ci]) : descendantsOf(cur[ci]);
          for (var pi = 0; pi < pool.length; pi++) {
            if (matchSimple(pool[pi], simple)) next.push(pool[pi]);
          }
        }
        if (simple.pseudo.length) next = applyPseudo(next, simple.pseudo);
        cur = next;
        childOnly = false;
      }
      for (var ii = 0; ii < cur.length; ii++) {
        if (out.indexOf(cur[ii]) < 0) out.push(cur[ii]);
      }
    }
    return out;
  }

  function Elements(list) {
    this.list = list || [];
    this.length = this.list.length;
    for (var i = 0; i < this.list.length; i++) this[i] = this.list[i];
  }

  Elements.prototype.size = function () { return this.list.length; };
  Elements.prototype.isEmpty = function () { return this.list.length === 0; };
  Elements.prototype.get = function (i) {
    var idx = i < 0 ? this.list.length + i : i;
    return this.list[idx] || null;
  };
  Elements.prototype.eq = function (i) { var e = this.get(i); return new Elements(e ? [e] : []); };
  Elements.prototype.first = function () { return this.list.length ? this.list[0] : null; };
  Elements.prototype.last = function () { return this.list.length ? this.list[this.list.length - 1] : null; };
  Elements.prototype.text = function () {
    var parts = [];
    for (var i = 0; i < this.list.length; i++) parts.push(this.list[i].text());
    return norm(parts.join(' '));
  };
  Elements.prototype.ownText = function () {
    var parts = [];
    for (var i = 0; i < this.list.length; i++) parts.push(this.list[i].ownText());
    return norm(parts.join(' '));
  };
  Elements.prototype.texts = function () {
    var out = [];
    for (var i = 0; i < this.list.length; i++) out.push(this.list[i].text());
    return out;
  };
  Elements.prototype.eachText = function () { return this.texts(); };
  Elements.prototype.attr = function (k) {
    for (var i = 0; i < this.list.length; i++) {
      var v = this.list[i].attr(k);
      if (v !== '' && v !== undefined && v !== null) return v;
    }
    return '';
  };
  Elements.prototype.hasAttr = function (k) {
    for (var i = 0; i < this.list.length; i++) if (this.list[i].hasAttr(k)) return true;
    return false;
  };
  Elements.prototype.html = function () { return this.list.length ? innerOf(this.list[0]) : ''; };
  Elements.prototype.outerHtml = function () {
    var out = '';
    for (var i = 0; i < this.list.length; i++) out += outerOf(this.list[i]);
    return out;
  };
  Elements.prototype.toString = function () { return this.outerHtml(); };
  Elements.prototype.select = function (sel) { return new Elements(selectAll(this.list, sel)); };
  Elements.prototype.each = function (fn) {
    for (var i = 0; i < this.list.length; i++) fn.call(this.list[i], i, this.list[i]);
    return this;
  };
  Elements.prototype.forEach = function (fn) {
    for (var i = 0; i < this.list.length; i++) fn(this.list[i], i);
  };
  Elements.prototype.map = function (fn) {
    var out = [];
    for (var i = 0; i < this.list.length; i++) out.push(fn(this.list[i], i));
    return out;
  };
  Elements.prototype.filter = function (fn) {
    var out = [];
    for (var i = 0; i < this.list.length; i++) if (fn(this.list[i], i)) out.push(this.list[i]);
    return new Elements(out);
  };
  Elements.prototype.toArray = function () { return this.list.slice(); };
  Elements.prototype.remove = function () {
    for (var i = 0; i < this.list.length; i++) {
      var e = this.list[i];
      if (!e.parent) continue;
      var idx = e.parent.kids.indexOf(e);
      if (idx >= 0) e.parent.kids.splice(idx, 1);
    }
    return this;
  };

  var Jsoup = {
    parse: function (html) { return parseHtml(html); },
    parseBodyFragment: function (html) { return parseHtml(html); },
    clean: function (html) { return parseHtml(html).text(); },
    isValid: function (html) { return String(html).indexOf('<') >= 0; }
  };

  return {
    jsoup: {
      Jsoup: Jsoup,
      nodes: { Document: parseHtml(''), Element: parseHtml('') },
      select: { Elements: Elements }
    }
  };
})();
''';
}
