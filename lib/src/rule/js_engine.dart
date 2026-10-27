import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_js/flutter_js.dart';

import '../core/rule_exception.dart';
import 'jsoup_shim.dart';

/// JS 里一次「需要回到 Dart 侧求值」的请求。
///
/// 说明：QuickJS 的 Dart 绑定只能传入代码、取回结果，无法把 Dart 函数同步
/// 注入给 JS。因此我们用「抛出-重放」的方式模拟同步调用：
///  1. `java.ajax(url)` 发现结果不在 `__novalCache` 里，就把 key 记进
///     `__novalPending` 然后 `throw`；
///  2. Dart 侧捕获到异常，读出 pending 列表，异步完成网络/加密运算；
///  3. 把结果写回 `__novalCache`，**重新执行**同一段代码；
///  4. 这次命中缓存，代码正常返回。
///
/// 这对书源规则是安全的：规则里的 JS 基本都是纯函数式取数，重放不会产生
/// 副作用（我们每轮都会重置 pending）。
class JsRequest {
  const JsRequest({
    required this.url,
    this.method = 'GET',
    this.body = '',
    this.headers,
  });

  final String url;
  final String method;
  final String body;
  final Map<String, String>? headers;
}

/// 网络取数回调。
typedef JsFetch = Future<String> Function(JsRequest request);

class JsEngine {
  /// 取数轮次的含义：JS 里每次 `java.ajax` 都是同步等待，引擎靠「抛错 →
  /// 外面取一次数据 → 重跑整段 JS」来模拟。**每轮只能多解决一个 URL**
  /// （JS 在第一个未命中的 ajax 处就 throw 了），所以漫画站那种「一个章节
  /// 几十页、每页一个接口」的规则，轮次上限必须够大（mangabz 实测 35 页）。
  JsEngine({required this.fetch, this.maxRounds = 160});

  /// ajax 取数实现。
  final JsFetch fetch;

  /// 单次规则求值允许的最大「取数轮次」。
  final int maxRounds;

  JavascriptRuntime? _rt;
  final Map<String, String> _cache = <String, String>{};

  static const String _prelude = r'''
var __novalPending = [];
var __novalCache = {};
var __novalResult = null;
var __novalPromise = null;
// 这些是每轮求值前由 Dart 侧覆写的「规则上下文变量」，先声明默认值，
// 否则预置脚本自身的 `source` 对象会因变量未定义而 ReferenceError。
var result = '';
var baseUrl = '';
var sourceUrl = '';
var sourceName = '';
var key = '';
var page = 1;
var searchKey = '';
var searchPage = 1;
// Legado 规则里常见的对象上下文，先给空壳，避免 ReferenceError
var book = { bookUrl: '', name: '', author: '', tocUrl: '', origin: '' };
var chapter = { url: '', title: '', index: 0 };

// 少数书源会把整段浏览器脚本（例如图片解密器）粘进规则里，它们通常会挂到 window 上，
// 并顺手读 location / document。这里给出最小可用的同名全局，避免 ReferenceError。
var window = globalThis;
var self = globalThis;
var navigator = { userAgent: '' };
var location = {
  hostname: '',
  href: '',
  origin: '',
  protocol: 'https:',
  pathname: '/',
  search: ''
};
var document = {
  createElement: function () {
    return { style: {}, innerHTML: '', setAttribute: function () {}, appendChild: function () {} };
  },
  head: { appendChild: function () {} },
  body: { appendChild: function () {}, style: {} },
  addEventListener: function () {},
  getElementById: function () { return null; },
  querySelectorAll: function () { return []; },
  currentScript: null
};

// QuickJS 没有 atob / TextDecoder，而站点自带的解密脚本基本都要用。
var __novalB64 =
  'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
var __novalB64Map = {};
for (var __i = 0; __i < __novalB64.length; __i++) {
  __novalB64Map[__novalB64.charAt(__i)] = __i;
}
var atob = function (input) {
  var s = String(input == null ? '' : input).replace(/[\s=]+/g, '');
  var out = '';
  var bits = 0;
  var acc = 0;
  for (var i = 0; i < s.length; i++) {
    var v = __novalB64Map[s.charAt(i)];
    if (v === undefined) continue;
    acc = (acc << 6) | v;
    bits += 6;
    if (bits >= 8) {
      bits -= 8;
      out += String.fromCharCode((acc >> bits) & 0xff);
    }
  }
  return out;
};
var btoa = function (input) {
  var s = String(input == null ? '' : input);
  var out = '';
  for (var i = 0; i < s.length; i += 3) {
    var c1 = s.charCodeAt(i) & 0xff;
    var c2 = i + 1 < s.length ? s.charCodeAt(i + 1) & 0xff : -1;
    var c3 = i + 2 < s.length ? s.charCodeAt(i + 2) & 0xff : -1;
    out += __novalB64.charAt(c1 >> 2);
    out += __novalB64.charAt(((c1 & 3) << 4) | (c2 < 0 ? 0 : c2 >> 4));
    out += c2 < 0 ? '=' : __novalB64.charAt(((c2 & 15) << 2) | (c3 < 0 ? 0 : c3 >> 6));
    out += c3 < 0 ? '=' : __novalB64.charAt(c3 & 63);
  }
  return out;
};
var TextDecoder = function (label) {
  this.encoding = label || 'utf-8';
  this.decode = function (bytes) {
    var arr = [];
    for (var i = 0; i < bytes.length; i++) arr.push(bytes[i]);
    var s = '';
    var i = 0;
    while (i < arr.length) {
      var b = arr[i++];
      if (b < 0x80) {
        s += String.fromCharCode(b);
      } else if (b >= 0xc0 && b < 0xe0) {
        s += String.fromCharCode(((b & 0x1f) << 6) | (arr[i++] & 0x3f));
      } else if (b >= 0xe0 && b < 0xf0) {
        var b2 = arr[i++];
        var b3 = arr[i++];
        s += String.fromCharCode(((b & 0x0f) << 12) | ((b2 & 0x3f) << 6) | (b3 & 0x3f));
      } else if (b >= 0xf0) {
        var c2 = arr[i++];
        var c3 = arr[i++];
        var c4 = arr[i++];
        var cp = ((b & 0x07) << 18) | ((c2 & 0x3f) << 12) | ((c3 & 0x3f) << 6) | (c4 & 0x3f);
        cp -= 0x10000;
        s += String.fromCharCode(0xd800 + (cp >> 10), 0xdc00 + (cp & 0x3ff));
      } else {
        s += '\ufffd';
      }
    }
    return s;
  };
};

// Dean Edwards packer 解码：不少漫画站把图片地址压成
//   eval(function(p,a,c,k,e,d){...}(...))
// 这里用捕获函数顶替 eval，把展开后的真实源码拿回来，再 eval 一次即可。
var __novalPackSrc = null;
function __novalCapturePack(s) {
  __novalPackSrc = String(s);
  return s;
}
function __unpack(payload) {
  var src = String(payload == null ? '' : payload);
  __novalPackSrc = null;
  src = src.replace(/^\s*eval\s*\(/, '__novalCapturePack(');
  try {
    eval(src);
  } catch (e) {
    return '';
  }
  return __novalPackSrc == null ? '' : __novalPackSrc;
}

function __novalHas(k) {
  return Object.prototype.hasOwnProperty.call(__novalCache, k);
}

function __novalResolve(k) {
  if (__novalHas(k)) return __novalCache[k];
  __novalPending.push(k);
  throw new Error('__NOVAL_NEED__');
}

function __novalAbs(u) {
  if (u === null || u === undefined) return '';
  u = String(u).trim();
  if (u === '') return '';
  if (/^https?:\/\//i.test(u)) return u;
  var b = String(baseUrl || '');
  if (u.indexOf('//') === 0) {
    var p = /^(https?:)/i.exec(b);
    return (p ? p[1] : 'https:') + u;
  }
  var m = /^(https?:\/\/[^\/?#]+)/i.exec(b);
  var origin = m ? m[1] : '';
  if (origin === '') return u;
  if (u.charAt(0) === '/') return origin + u;
  var path = b.replace(/[?#].*$/, '');
  var idx = path.lastIndexOf('/');
  var dir = idx > origin.length ? path.substring(0, idx + 1) : origin + '/';
  return dir + u;
}

function __novalStringify(v) {
  if (v === undefined || v === null) return '';
  if (typeof v === 'string') return v;
  if (typeof v === 'number' || typeof v === 'boolean') return String(v);
  if (typeof v === 'object') {
    // jsoup 的 Element / Elements 直接转字符串时取文本，避免输出 JSON 噪音
    try {
      if (typeof v.text === 'function') return String(v.text());
      if (typeof v.outerHtml === 'function') return String(v.outerHtml());
    } catch (e) { /* 忽略 */ }
  }
  try {
    return JSON.stringify(v);
  } catch (e) {
    return String(v);
  }
}

var java = {
  ajax: function (url) {
    var u = __novalAbs(url);
    return __novalResolve('ajax|' + JSON.stringify([String(baseUrl || ''), 'GET', u, '']));
  },
  get: function (url) {
    var u = __novalAbs(url);
    return __novalResolve('ajax|' + JSON.stringify([String(baseUrl || ''), 'GET', u, '']));
  },
  post: function (url, body) {
    var u = __novalAbs(url);
    return __novalResolve('ajax|' + JSON.stringify([String(baseUrl || ''), 'POST', u, body === undefined ? '' : String(body)]));
  },
  connect: function (url) {
    var u = __novalAbs(url);
    return __novalResolve('ajax|' + JSON.stringify([String(baseUrl || ''), 'GET', u, '']));
  },
  base64Encode: function (str) {
    return __novalResolve('b64e|' + String(str));
  },
  base64Decode: function (str) {
    return __novalResolve('b64d|' + String(str));
  },
  md5Encode: function (str) {
    return __novalResolve('md5|' + String(str));
  },
  md5Encode16: function (str) {
    return __novalResolve('md5_16|' + String(str));
  },
  urlEncode: function (str) {
    return encodeURIComponent(String(str));
  },
  timeFormat: function (t) {
    return __novalResolve('time|' + String(t));
  },
  log: function (msg) {
    return __novalResolve('log|' + String(msg));
  },
  toast: function (msg) {
    return __novalResolve('log|' + String(msg));
  }
};

var cookie = {
  getCookie: function () { return ''; },
  setCookie: function () { return ''; },
  removeCookie: function () { return ''; }
};

var source = {
  bookSourceUrl: sourceUrl || '',
  bookSourceName: sourceName || '',
  getKey: function () { return result; }
};

function __novalRun(code) {
  __novalPending = [];
  var v = eval(code);
  // 有些规则（例如整段粘贴进来的图片解密脚本）返回 Promise，必须等它 resolve
  // 才能拿到真正的字符串结果；Dart 侧会做「注册 + 轮询」把它等出来。
  if (v && typeof v.then === 'function') {
    __novalPromise = v.then(function (x) {
      __novalResult = x;
      return __novalStringify(x);
    });
    return __novalPromise;
  }
  __novalResult = v;
  return __novalStringify(v);
}
''';

  Future<List<String>> run(
    String code, {
    String result = '',
    String baseUrl = '',
    String sourceUrl = '',
    String sourceName = '',
    String key = '',
    int page = 1,
    Map<String, String> headers = const <String, String>{},
  }) async {
    final JavascriptRuntime rt = _runtime();
    _installPrelude(rt);

    for (int round = 0; round <= maxRounds; round++) {
      _setVar(rt, 'result', result);
      _setVar(rt, 'baseUrl', baseUrl);
      _setVar(rt, 'sourceName', sourceName);
      _setVar(rt, 'sourceUrl', sourceUrl);
      rt.evaluate(
        'key = ${jsonEncode(key)};'
        'page = $page;'
        'searchKey = key;'
        'searchPage = page;'
        'if (baseUrl) { book.bookUrl = baseUrl; book.origin = baseUrl; }'
        'if (baseUrl) { chapter.url = baseUrl; }',
      );
      rt.evaluate(
        'source.bookSourceUrl = ${jsonEncode(sourceUrl)};'
        'source.bookSourceName = ${jsonEncode(sourceName)};',
      );
      // 让 location 跟随当前页面地址：有的解密脚本会校验 location.hostname 白名单。
      rt.evaluate(
        '(function(){var u = ${jsonEncode(baseUrl)};'
        'location.href = u;'
        'var m = /^(https?:)\\/\\/([^\\/?#]+)/i.exec(u);'
        'location.hostname = m ? m[2] : "";'
        'location.origin = m ? m[1] + "//" + m[2] : "";'
        '})()',
      );

      JsEvalResult r;
      try {
        r = rt.evaluate('__novalRun(${jsonEncode(code)})');
        if (_isPromiseResult(r)) {
          r = await _drainPromise(rt, r);
        }
      } catch (e) {
        // 规则内部抛错（含 __NOVAL_NEED__ 哨兵）时这里会抛；pending 分支会接着处理。
        r = JsEvalResult('$e', null, isError: true);
      }
      final List<String> keys = _readPending(rt)
          .where((String k) => !_cache.containsKey(k))
          .toList();
      if (!r.isError && keys.isEmpty) {
        return _split(r.stringResult);
      }
      if (keys.isEmpty) {
        throw RuleException('JS 规则执行出错', detail: r.stringResult);
      }
      bool progressed = false;
      for (final String key in keys) {
        if (_cache.containsKey(key)) continue;
        try {
          _cache[key] = await _resolveKey(key, headers);
        } catch (e) {
          _cache[key] = '';
        }
        progressed = true;
      }
      if (!progressed) {
        throw RuleException('JS 规则无法解析依赖', detail: keys.join('\n'));
      }
      _injectCache(rt);
    }
    throw RuleException('JS 规则取数轮次超过上限（可能存在循环请求）');
  }

  Future<String> runString(
    String code, {
    String result = '',
    String baseUrl = '',
    String sourceUrl = '',
    String sourceName = '',
    String key = '',
    int page = 1,
    Map<String, String> headers = const <String, String>{},
  }) async {
    final List<String> list = await run(
      code,
      result: result,
      baseUrl: baseUrl,
      sourceUrl: sourceUrl,
      sourceName: sourceName,
      key: key,
      page: page,
      headers: headers,
    );
    return list.isEmpty ? '' : list.first;
  }

  /// QuickJS 返回 Promise 时，`evaluate` 拿到的是 Promise 对象本身（字符串形如
  /// `Instance of 'Future<dynamic>'`），需要自己把它「跑完」。
  bool _isPromiseResult(JsEvalResult r) {
    if (r.isPromise) return true;
    return r.stringResult.contains("Instance of 'Future");
  }

  /// 把 `__novalPromise` 注册进 flutter_js 的可查询 Promise 表，轮询到 settled 后取回值。
  ///
  /// flutter_js 的 QuickJS 实现里 `evaluateAsync` 只是 `evaluate` 的壳子，不能真正等待，
  /// 所以这里手动 pump：每轮先让引擎跑一次空的 eval/executePendingJob 驱动微任务队列。
  Future<JsEvalResult> _drainPromise(
    JavascriptRuntime rt,
    JsEvalResult initial,
  ) async {
    int idx = -1;
    try {
      idx = int.tryParse(
            rt.evaluate('FLUTTER_NATIVEJS_REGISTER_PROMISE(__novalPromise)')
                .stringResult
                .trim(),
          ) ??
          -1;
    } catch (_) {
      idx = -1;
    }
    if (idx < 0) return initial;

    bool pending = true;
    for (int i = 0; i < 600 && pending; i++) {
      try {
        rt.executePendingJob();
      } catch (_) {}
      // 一次空 eval 会把 QuickJS 的 job queue 推进一步
      rt.evaluate('0');
      pending = rt
          .evaluate('FLUTTER_NATIVEJS_IS_PENDING_PROMISE($idx)')
          .stringResult
          .trim() ==
          'true';
      if (pending) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    JsEvalResult out = initial;
    final bool fulfilled = rt
            .evaluate('FLUTTER_NATIVEJS_IS_FULLFILLED_PROMISE($idx)')
            .stringResult
            .trim() ==
        'true';
    if (fulfilled) {
      final JsEvalResult v =
          rt.evaluate('String(FLUTTER_NATIVEJS_PENDING_PROMISES[$idx].getValue())');
      out = JsEvalResult(v.stringResult, v.rawResult);
    } else {
      String reason = 'Promise 未完成';
      try {
        reason = rt
            .evaluate('String(FLUTTER_NATIVEJS_PENDING_PROMISES[$idx].getValue())')
            .stringResult;
      } catch (_) {}
      out = JsEvalResult(reason, initial.rawResult, isError: true);
    }
    try {
      rt.evaluate('FLUTTER_NATIVEJS_CLEAN_PROMISE($idx)');
    } catch (_) {}
    return out;
  }

  /// 切换书源时清空上下文（缓存里可能有上一本书的加密参数）。
  void reset() {
    _cache.clear();
    _preludeInstalled = false;
    try {
      _rt?.dispose();
    } catch (_) {}
    _rt = null;
  }

  void dispose() => reset();

  // ---------------------------------------------------------------- internals

  JavascriptRuntime _runtime() {
    var rt = _rt;
    if (rt != null) return rt;
    rt = getJavascriptRuntime(xhr: false);
    _rt = rt;
    return rt;
  }

  bool _preludeInstalled = false;

  void _installPrelude(JavascriptRuntime rt) {
    if (_preludeInstalled) return;
    final JsEvalResult r = rt.evaluate('$_prelude\n${JsoupShim.source}');
    if (r.isError) {
      throw RuleException('JS 引擎初始化失败', detail: r.stringResult);
    }
    _preludeInstalled = true;
    if (_cache.isNotEmpty) _injectCache(rt);
  }

  void _setVar(JavascriptRuntime rt, String name, String value) {
    rt.evaluate('var $name = ${jsonEncode(value)};');
  }

  void _injectCache(JavascriptRuntime rt) {
    final StringBuffer sb = StringBuffer();
    _cache.forEach((String k, String v) {
      sb.writeln('__novalCache[${jsonEncode(k)}] = ${jsonEncode(v)};');
    });
    if (sb.isEmpty) return;
    rt.evaluate(sb.toString());
  }

  List<String> _readPending(JavascriptRuntime rt) {
    final JsEvalResult r = rt.evaluate('JSON.stringify(__novalPending)');
    if (r.isError) return const <String>[];
    final String s = r.stringResult;
    if (s.isEmpty || s == 'undefined' || s == 'null') return const <String>[];
    try {
      final Object? v = jsonDecode(s);
      if (v is List) {
        return v
            .where((Object? e) => e != null)
            .map((Object? e) => e.toString())
            .toList();
      }
    } catch (_) {
      // ignore
    }
    return const <String>[];
  }

  Future<String> _resolveKey(String key, Map<String, String> headers) async {
    final int bar = key.indexOf('|');
    if (bar < 0) return '';
    final String kind = key.substring(0, bar);
    final String payload = key.substring(bar + 1);

    switch (kind) {
      case 'ajax':
        final Object? decoded = jsonDecode(payload);
        if (decoded is! List || decoded.length < 4) return '';
        final String baseUrl = decoded[0]?.toString() ?? '';
        final String method = decoded[1]?.toString() ?? 'GET';
        final String url = decoded[2]?.toString() ?? '';
        final String body = decoded[3]?.toString() ?? '';
        final String finalUrl =
            url.isEmpty ? baseUrl : _resolve(baseUrl, url);
        final String text =
            await fetch(JsRequest(url: finalUrl, method: method, body: body, headers: headers));
        return text;
      case 'md5':
        return md5.convert(utf8.encode(payload)).toString();
      case 'md5_16':
        return md5.convert(utf8.encode(payload)).toString().substring(8, 24);
      case 'b64e':
        return base64Encode(utf8.encode(payload));
      case 'b64d':
        try {
          return utf8.decode(base64Decode(payload));
        } catch (_) {
          return '';
        }
      case 'time':
        final int ts = int.tryParse(payload) ??
            (payload.isEmpty ? 0 : DateTime.now().millisecondsSinceEpoch);
        final int ms = ts > 100000000000 ? ts : ts * 1000;
        final DateTime d = DateTime.fromMillisecondsSinceEpoch(ms);
        String two(int v) => v.toString().padLeft(2, '0');
        return '${d.year}/${two(d.month)}/${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
      case 'log':
        // ignore: avoid_print
        print('[source-js] $payload');
        return '';
      default:
        return '';
    }
  }

  String _resolve(String baseUrl, String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (baseUrl.isEmpty) return url;
    try {
      return Uri.parse(baseUrl).resolve(url).toString();
    } catch (_) {
      return url;
    }
  }

  List<String> _split(String raw) {
    final String s = raw.trim();
    if (s.isEmpty || s == 'undefined' || s == 'null') return const <String>[];
    // JS 返回数组/对象时我们 stringify 过，重新展开成列表
    if (s.startsWith('[')) {
      try {
        final Object? v = jsonDecode(s);
        if (v is List) {
          return v
              .where((Object? e) => e != null)
              .map((Object? e) => e is String ? e : jsonEncode(e))
              .where((String e) => e.isNotEmpty)
              .toList();
        }
      } catch (_) {
        // 不是合法 JSON，按普通字符串处理
      }
    }
    return <String>[s];
  }
}
