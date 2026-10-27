import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../core/version.dart';
import '../model/book_source.dart';
import '../model/shelf_book.dart';
import '../net/net_diag.dart';
import '../net/net_diag_page.dart';
import 'source_page.dart';
import 'theme/app_theme.dart';
import 'theme/theme_sheet.dart';
import 'motion.dart';
import 'update_entry.dart';
import 'widgets.dart';

/// 「我的」：书源管理、主题外观、关于，都收在这一页里。
class MinePage extends StatelessWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final AppPalette p = context.palette;
    final int localCount = state.shelf
        .where((ShelfBook b) => b.bookUrl.startsWith('local://'))
        .length;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpace.xxl),
        children: <Widget>[
          PageHeader(
            title: '我的',
            subtitle: '墨町 · 本地优先，规则自定',
            actions: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => showThemeSheet(context),
                child: Padding(
                  padding: const EdgeInsets.only(left: AppSpace.sm),
                  child: Icon(Icons.palette_outlined, size: 22, color: p.ink),
                ),
              ),
            ],
          ),

          // ---- 概览 ----
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
            child: AppCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
              child: Row(
                children: <Widget>[
                  Expanded(child: _Stat(value: '${state.sources.length}', label: '书源')),
                  _Divider(color: p.line),
                  Expanded(child: _Stat(value: '${state.shelf.length}', label: '书架')),
                  _Divider(color: p.line),
                  Expanded(child: _Stat(value: '$localCount', label: '本地导入')),
                ],
              ),
            ),
          ),

          // ---- 书源 ----
          const SectionHeader(title: '内容源'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
            child: Column(
              children: <Widget>[
                AppCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.lg, vertical: AppSpace.md),
                  onTap: () => Navigator.of(context).push(
                    fadeSlideRoute<void>(const SourcePage()),
                  ),
                  child: _Entry(
                    icon: Icons.layers_outlined,
                    title: '书源管理',
                    subtitle: '${state.sources.length} 个源 · 导入 / 导出 / 体检',
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                AppCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.lg, vertical: AppSpace.md),
                  onTap: () => _openNetDiag(context, state),
                  child: _Entry(
                    icon: Icons.wifi_tethering,
                    title: '网络诊断',
                    subtitle: '全部书源的域名逐个探一遍：通了才谈得上解析',
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                AppCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.lg, vertical: AppSpace.md),
                  onTap: () => _openCfVerify(context, state),
                  child: _Entry(
                    icon: Icons.verified_user_outlined,
                    title: '浏览器过验证',
                    subtitle: '站点要求人机验证时，用内置浏览器过一次并保存 Cookie',
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                AppCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.lg, vertical: AppSpace.md),
                  onTap: () => _pasteCookie(context, state),
                  child: _Entry(
                    icon: Icons.content_paste_go,
                    title: '粘贴 Cookie',
                    subtitle: '内置浏览器打不开时：在电脑浏览器过完验证，把 Cookie 贴进来',
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                AppCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.lg, vertical: AppSpace.md),
                  child: _Entry(
                    icon: Icons.bookmark_added_outlined,
                    title: '本地导入',
                    subtitle: '书架页右上角的 ＋ 号，可导入 TXT / EPUB',
                    trailing: const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),

          // ---- 外观 ----
          const SectionHeader(title: '外观'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
            child: AppCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.lg, vertical: AppSpace.md),
              onTap: () => showThemeSheet(context),
              child: _Entry(
                icon: Icons.palette_outlined,
                title: '主题',
                subtitle: '当前：${state.theme.label}',
              ),
            ),
          ),

          // ---- 关于 ----
          const SectionHeader(title: '关于'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
            child: Column(
              children: <Widget>[
                const UpdateEntry(),
                const SizedBox(height: AppSpace.md),
                AppCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.lg, vertical: AppSpace.md),
                  onTap: () => _showAbout(context),
                  child: _Entry(
                    icon: Icons.info_outline,
                    title: '关于墨町',
                    subtitle: 'v$kAppVersion · 自用阅读器',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 把所有书源里出现过的域名抓出来逐个探一遍。
  void _openNetDiag(BuildContext context, AppState state) {
    final List<String> texts = <String>[];
    for (final BookSource s in state.sources) {
      texts.add(s.url);
      try {
        texts.add(jsonEncode(s.raw));
      } on Object {
        texts.add(s.searchUrl);
      }
    }
    final List<String> hosts = NetDiag.hostsOf(texts);
    Navigator.of(context).push<void>(
      fadeSlideRoute(
        NetDiagPage(
          title: '网络诊断',
          hosts: hosts,
          note: '按书源里出现的域名逐个试：先解析 DNS，再请求首页。'
              '全红说明网络到不了站点（多半要代理），红黄相间多半是站点侧反爬。',
        ),
      ),
    );
  }


  /// 让用户填一个地址，开内置浏览器过验证，把 Cookie 灌进引擎的 CookieJar。
  ///
  /// 和书源行里的「浏览器过验证」是同一套管道，区别只是这里不依赖具体书源：
  /// 站点还没写成规则、或者规则里的 host 和你想验证的 host 不一致时用这个。
  Future<void> _openCfVerify(BuildContext context, AppState state) async {
    // 内置 WebView 在部分平台取不到站点 Cookie，统一改走手动粘贴。
    await _pasteCookie(context, state);
  }



  /// 手动粘贴 Cookie：内置浏览器打不开站点（DNS 被污染、WebView 起不来）时的后路。
  Future<void> _pasteCookie(BuildContext context, AppState state) async {
    final TextEditingController hostCtrl = TextEditingController(
        text: state.sources.isEmpty ? '' : _hostOf(state.sources.first.url));
    final TextEditingController cookieCtrl = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('粘贴 Cookie'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: hostCtrl,
                decoration: const InputDecoration(
                  labelText: '站点域名',
                  hintText: '18comic.vip',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cookieCtrl,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Cookie',
                  hintText: 'cf_clearance=xxxx; other=yyy',
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    String host = hostCtrl.text.trim();
    if (host.contains('://')) host = Uri.tryParse(host)?.host ?? host;
    final int n =
        await state.engine.http.importCookieHeader(host, cookieCtrl.text);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(n > 0 ? '已保存 $n 条 Cookie（$host）' : '没解析出 Cookie，格式应为 a=1; b=2'),
      ),
    );
  }

  String _hostOf(String url) => Uri.tryParse(url)?.host ?? '';

  void _showAbout(BuildContext context) {
    final AppPalette p = context.palette;
    showDialog<void>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        backgroundColor: p.surface,
        title: Text('墨町', style: c.text.titleMedium),
        content: Text(
          '一个只做框架的阅读器：小说与漫画都靠书源规则（Legado 书源 JSON）驱动，'
          '内容全部来自你导入的源，App 本身不内置任何内容。\n\n'
          '支持 TXT / EPUB 本地书、上下滚动与左右翻页两种阅读模式。',
          style: c.text.bodyMedium,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Column(
      children: <Widget>[
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: p.ink,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: context.text.bodySmall),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 26, color: color);
}

class _Entry extends StatelessWidget {
  const _Entry({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return Row(
      children: <Widget>[
        Icon(icon, size: 19, color: p.primary),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: p.ink,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 3),
              Text(subtitle, style: context.text.bodySmall),
            ],
          ),
        ),
        trailing ??
            Icon(Icons.chevron_right, size: 18, color: p.inkFaint),
      ],
    );
  }
}
