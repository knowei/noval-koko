import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../model/source_subscription.dart';
import 'motion.dart';
import 'theme/app_theme.dart';
import 'widgets.dart';

/// 书源订阅：一个 URL 拉一整套书源，以后点一下就同步。
///
/// 相比“导入一个 JSON 文件”，订阅的好处是源更新了你不用重新找文件；
/// 相比“我自己维护源”，好处是别人修好了你直接吃到。
class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final Set<String> _busy = <String>{};

  Future<void> _sync(SourceSubscription sub) async {
    if (_busy.contains(sub.url)) return;
    setState(() => _busy.add(sub.url));
    final AppState state = context.read<AppState>();
    String msg;
    try {
      msg = await state.syncSubscription(sub);
    } on Object catch (e) {
      msg = '同步失败：$e';
    }
    if (!mounted) return;
    setState(() => _busy.remove(sub.url));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _add() async {
    final TextEditingController ctrl = TextEditingController();
    String? clipboard;
    try {
      final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
      clipboard = data?.text?.trim();
    } on Object {
      clipboard = null;
    }
    if (clipboard != null &&
        !clipboard.startsWith('http') &&
        clipboard.length > 200) {
      clipboard = null; // 剪贴板里是别的长文本，别预填
    }
    if (!mounted) return;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) {
        final AppPalette p = c.palette;
        return AlertDialog(
          backgroundColor: p.surface,
          title: Text('添加订阅', style: c.text.titleMedium),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '填一个能返回书源 JSON 的地址（GitHub raw、gist、jsDelivr 都行）。'
                '拉下来会按 bookSourceUrl 合并，同名的源直接覆盖。',
                style: c.text.bodySmall?.copyWith(color: p.inkMid),
              ),
              const SizedBox(height: AppSpace.md),
              TextField(
                controller: ctrl,
                autofocus: true,
                minLines: 1,
                maxLines: 3,
                style: c.text.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'https://raw.githubusercontent.com/... .json',
                  hintStyle: c.text.bodySmall?.copyWith(color: p.inkFaint),
                  suffixIcon: clipboard == null
                      ? null
                      : IconButton(
                          tooltip: '粘贴剪贴板',
                          icon: const Icon(Icons.content_paste, size: 18),
                          onPressed: () => ctrl.text = clipboard!,
                        ),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('添加并同步'),
            ),
          ],
        );
      },
    );
    final String url = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || url.isEmpty || !mounted) return;

    final AppState state = context.read<AppState>();
    setState(() => _busy.add(url));
    String msg;
    try {
      msg = await state.addSubscription(url);
    } on Object catch (e) {
      msg = '添加失败：$e';
    }
    if (!mounted) return;
    setState(() => _busy.remove(url));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _remove(SourceSubscription sub) async {
    final AppState state = context.read<AppState>();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        backgroundColor: c.palette.surface,
        title: Text('删除订阅？', style: c.text.titleMedium),
        content: Text(
          '「${sub.displayName}」的订阅记录会被删掉，已经导入的书源不受影响。',
          style: c.text.bodyMedium,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) await state.removeSubscription(sub.url);
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final AppState state = context.watch<AppState>();
    final List<SourceSubscription> subs = state.subscriptions;

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            PageHeader(
              title: '书源订阅',
              subtitle: subs.isEmpty
                  ? '还没订阅，加一个地址试试'
                  : '${subs.length} 个订阅 · 同步会按源地址合并',
              leading: IconButton(
                tooltip: '返回',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              actions: <Widget>[
                IconButton(
                  tooltip: '添加订阅',
                  icon: const Icon(Icons.add_link),
                  onPressed: _add,
                ),
              ],
            ),
            Expanded(
              child: subs.isEmpty
                  ? const EmptyHint(
                      icon: Icons.rss_feed,
                      title: '没有订阅',
                      subtitle: '右上角加一个书源集合地址，'
                          '以后源更新了点一下就同步，不用重新找文件。',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.page,
                        0,
                        AppSpace.page,
                        AppSpace.xl,
                      ),
                      itemCount: subs.length,
                      separatorBuilder: (BuildContext c, int i) =>
                          const SizedBox(height: AppSpace.sm),
                      itemBuilder: (BuildContext c, int i) {
                        final SourceSubscription sub = subs[i];
                        return FadeSlideIn(
                          delay: Duration(milliseconds: 24 * i),
                          child: _SubRow(
                            sub: sub,
                            busy: _busy.contains(sub.url),
                            onSync: () => _sync(sub),
                            onRemove: () => _remove(sub),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubRow extends StatelessWidget {
  const _SubRow({
    required this.sub,
    required this.busy,
    required this.onSync,
    required this.onRemove,
  });

  final SourceSubscription sub;
  final bool busy;
  final VoidCallback onSync;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    return AppCard(
      onTap: busy ? null : onSync,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  sub.displayName,
                  style: context.text.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  sub.url,
                  style: context.text.bodySmall?.copyWith(color: p.inkFaint),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${sub.count} 个源 · ${sub.lastSyncText}',
                  style: context.text.bodySmall?.copyWith(color: p.inkMid),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          if (busy)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...<Widget>[
            IconButton(
              tooltip: '立即同步',
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: onSync,
            ),
            IconButton(
              tooltip: '删除订阅',
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: onRemove,
            ),
          ],
        ],
      ),
    );
  }
}
