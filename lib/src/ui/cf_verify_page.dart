import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as wv;

import '../net/http_service.dart';
import 'theme/app_theme.dart';

/// 浏览器过验证页。
///
/// 用途：有些站点（典型是 Cloudflare 的 Managed Challenge）会把人机验证的
/// Cookie（`cf_clearance`）和 UA 绑在一起，只在真浏览器里过一次才能拿到。
/// 规则引擎拿不到这个 Cookie，于是所有请求 403「站点要求人机验证」。
///
/// 这个页面把站点装进真正的 WebView 里，让用户在浏览器环境里过验证，
/// 点「完成」时把当前域名的 Cookie 全部收回来，交给 HttpService 持久化，
/// 之后的规则请求就自动带上它们，直到过期。
class CfVerifyPage extends StatefulWidget {
  const CfVerifyPage({
    super.key,
    required this.startUrl,
    required this.host,
  });

  /// 要打开的地址，一般就是书源站点的根，例如 `https://18comic.vip/`。
  final String startUrl;

  /// Cookie 归属的域名，用于回传时归并。
  final String host;

  @override
  State<CfVerifyPage> createState() => _CfVerifyPageState();
}

class _CfVerifyPageState extends State<CfVerifyPage> {
  wv.InAppWebViewController? _controller;
  bool _loading = true;
  String _title = '';
  String _currentUrl = '';
  int _cookieCount = 0;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.startUrl;
  }

  Future<List<ImportedCookie>> _collect() async {
    final List<ImportedCookie> out = <ImportedCookie>[];
    final Set<String> seen = <String>{};
    final List<String> urls = <String>{
      widget.startUrl,
      _currentUrl,
      'https://${widget.host}/',
    }.where((String u) => u.isNotEmpty).toList();
    for (final String u in urls) {
      try {
        final List<wv.Cookie> list =
            await wv.CookieManager.instance().getCookies(url: wv.WebUri(u));
        for (final wv.Cookie c in list) {
          final String key = '${c.name}=${c.value}@${c.domain}';
          if (!seen.add(key)) continue;
          out.add(
            ImportedCookie(
              c.name,
              c.value,
              domain: c.domain ?? '',
              path: c.path ?? '/',
            ),
          );
        }
      } on Object {
        // 某些平台/域名取不到就跳过，不该让整个流程失败。
      }
    }
    return out;
  }

  Future<void> _refreshCount() async {
    final List<ImportedCookie> list = await _collect();
    if (!mounted) return;
    setState(() => _cookieCount = list.length);
  }

  Future<void> _finish() async {
    final List<ImportedCookie> cookies = await _collect();
    if (!mounted) return;
    if (cookies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没拿到 Cookie，先在上面把页面点开、过完验证再试')),
      );
      return;
    }
    Navigator.of(context).pop(cookies);
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('浏览器过验证 · ${widget.host}'),
            if (_title.isNotEmpty)
              Text(
                _title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall,
              ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: '刷新',
            onPressed: () => _controller?.reload(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            color: palette.surfaceAlt,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Text(
              '在下面的浏览器里正常打开站点、过掉人机验证（能看到页面内容即算通过），'
              '然后点底部「完成」。墨町会把 Cookie 存下来，后面规则请求自动带上，不用再开浏览器。',
              style: context.text.bodySmall,
            ),
          ),
          Expanded(
            child: Stack(
              children: <Widget>[
                wv.InAppWebView(
                  initialUrlRequest:
                      wv.URLRequest(url: wv.WebUri(widget.startUrl)),
                  initialSettings: wv.InAppWebViewSettings(
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    mediaPlaybackRequiresUserGesture: true,
                  ),
                  onWebViewCreated: (wv.InAppWebViewController c) {
                    _controller = c;
                  },
                  onLoadStart: (wv.InAppWebViewController c, wv.WebUri? url) {
                    setState(() {
                      _loading = true;
                      if (url != null) _currentUrl = url.toString();
                    });
                  },
                  onLoadStop: (wv.InAppWebViewController c, wv.WebUri? url) async {
                    if (!mounted) return;
                    setState(() {
                      _loading = false;
                      if (url != null) _currentUrl = url.toString();
                    });
                    await _refreshCount();
                    try {
                      final String? title = await c.getTitle();
                      if (mounted && title != null) setState(() => _title = title);
                    } on Object {
                      // 标题取不到无所谓。
                    }
                  },
                  onReceivedError: (wv.InAppWebViewController c,
                      wv.WebResourceRequest r, wv.WebResourceError e) {
                    if (!mounted) return;
                    setState(() => _loading = false);
                  },
                ),
                if (_loading)
                  const Align(
                    alignment: Alignment.topCenter,
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _cookieCount == 0
                          ? '当前还没抓到 Cookie'
                          : '已就绪：$_cookieCount 条 Cookie',
                      style: context.text.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _finish,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('完成'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
