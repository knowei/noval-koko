import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../core/version.dart';
import '../model/shelf_book.dart';
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
