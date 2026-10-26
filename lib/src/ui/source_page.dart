import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../model/book_source.dart';
import 'motion.dart';
import 'theme/app_theme.dart';
import 'widgets.dart';

/// 书源管理：导入 / 启停 / 体检 / 删除 / 导出。
class SourcePage extends StatefulWidget {
  const SourcePage({super.key});

  @override
  State<SourcePage> createState() => _SourcePageState();
}

class _SourcePageState extends State<SourcePage> {
  bool _busy = false;

  /// 体检结果：null 未测 / true 可用 / false 失效。
  final Map<String, bool?> _health = <String, bool?>{};
  final TextEditingController _query = TextEditingController();
  String _filter = 'all';
  int _checked = 0;
  int _toCheck = 0;
  bool _checking = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------- importing

  Future<void> _importFromText(String text) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final int n = await context.read<AppState>().importText(text);
      _toast('成功导入 $n 个书源');
    } catch (e) {
      _toast('导入失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importFromClipboard() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String? text = data?.text;
    if (text == null || text.trim().isEmpty) {
      _toast('剪贴板是空的');
      return;
    }
    await _importFromText(text);
  }

  Future<void> _importFromFile() async {
    try {
      final List<PlatformFile> files = await FilePicker.pickFiles(
        dialogTitle: '选择书源 JSON 文件',
      );
      if (files.isEmpty) return;
      final Uint8List bytes = await files.first.readAsBytes();
      if (bytes.isEmpty) {
        _toast('文件是空的');
        return;
      }
      await _importFromText(utf8.decode(bytes, allowMalformed: true));
    } catch (e) {
      _toast('读取文件失败：$e');
    }
  }

  Future<void> _openPasteDialog() async {
    final TextEditingController controller = TextEditingController();
    final String? text = await showDialog<String>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('粘贴书源 JSON'),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: controller,
            maxLines: 12,
            minLines: 6,
            decoration: const InputDecoration(
              hintText: '支持单个书源对象、书源数组，或每行一个书源 JSON',
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              final ClipboardData? data =
                  await Clipboard.getData(Clipboard.kTextPlain);
              if (data?.text != null) controller.text = data!.text!;
            },
            child: const Text('读剪贴板'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(controller.text),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text != null && text.trim().isNotEmpty) await _importFromText(text);
  }

  Future<void> _export() async {
    final String json = await context.read<AppState>().exportSources();
    if (json.trim().isEmpty || json.trim() == '[]') {
      _toast('没有书源可导出');
      return;
    }
    await Clipboard.setData(ClipboardData(text: json));
    _toast('全部书源 JSON 已复制到剪贴板');
  }

  // ---------------------------------------------------------------- checking

  /// 轻量体检：拿每个源搜一下（有关键词用 checkKeyWord，否则用源名），
  /// 只要请求没抛异常就算「可用」。0 条结果不代表失效。
  Future<void> _check() async {
    if (_checking) return;
    final AppState state = context.read<AppState>();
    final List<BookSource> targets = state.sources
        .where((BookSource s) => s.enabled && s.canSearch)
        .toList();
    if (targets.isEmpty) {
      _toast('没有可检测的书源');
      return;
    }
    setState(() {
      _checking = true;
      _checked = 0;
      _toCheck = targets.length;
      _health.clear();
    });

    for (final BookSource s in targets) {
      final String custom = s.ruleSearch.checkKeyWord.trim();
      final String key = custom.isNotEmpty ? custom : '剑来';
      bool ok;
      try {
        await state.engine
            .search(s, key)
            .timeout(const Duration(seconds: 20));
        ok = true;
      } catch (_) {
        ok = false;
      }
      if (!mounted) return;
      setState(() {
        _health[s.url] = ok;
        _checked++;
      });
      await state.reloadSources();
    }

    if (mounted) {
      setState(() => _checking = false);
      _toast('检测完成');
    }
  }

  int _countWhere(List<BookSource> list, bool? want) => list
      .where((BookSource s) => _health.containsKey(s.url) && _health[s.url] == want)
      .length;

  // ----------------------------------------------------------------- actions

  Future<void> _showActions(BookSource s) async {
    final AppState state = context.read<AppState>();
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              title: Text(s.name, style: context.text.titleMedium),
              subtitle: Text(s.url, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.data_object),
              title: const Text('查看 JSON'),
              onTap: () {
                Navigator.of(c).pop();
                _showJson(s);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: context.palette.bad),
              title: Text('删除该书源', style: TextStyle(color: context.palette.bad)),
              onTap: () async {
                Navigator.of(c).pop();
                await state.deleteSources(<String>[s.url]);
                _toast('已删除 ${s.name}');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showJson(BookSource s) {
    showDialog<void>(
      context: context,
      builder: (BuildContext c) {
        final String text =
            const JsonEncoder.withIndent('  ').convert(s.toJson());
        return AlertDialog(
          title: Text(s.name),
          content: SizedBox(
            width: 560,
            height: 400,
            child: SingleChildScrollView(
              child: SelectableText(
                text,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (c.mounted) Navigator.of(c).pop();
                _toast('已复制');
              },
              child: const Text('复制'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(c).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
      ));
  }

  // -------------------------------------------------------------------- view

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final AppState state = context.watch<AppState>();
    final List<BookSource> all = state.sources;

    final int ok = _countWhere(all, true);
    final int bad = _countWhere(all, false);
    final int idle = all.length - ok - bad;

    final String q = _query.text.trim().toLowerCase();
    final List<BookSource> list = all.where((BookSource s) {
      if (q.isNotEmpty &&
          !s.name.toLowerCase().contains(q) &&
          !s.url.toLowerCase().contains(q)) {
        return false;
      }
      switch (_filter) {
        case 'ok':
          return _health[s.url] == true;
        case 'bad':
          return _health[s.url] == false;
        case 'idle':
          return _health[s.url] == null;
        default:
          return true;
      }
    }).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            PageHeader(
              title: '书源管理',
              subtitle: '导入 / 导出 / 批量体检',
              leading: Navigator.of(context).canPop()
                  ? _HeaderAction(
                      icon: Icons.arrow_back,
                      onTap: () => Navigator.of(context).pop(),
                    )
                  : null,
              actions: <Widget>[
                if (_busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                _HeaderAction(
                  icon: Icons.add_circle_outline,
                  onTap: () => _showImportMenu(),
                ),
                _HeaderAction(
                  icon: Icons.tune,
                  onTap: () => _showBatchMenu(),
                ),
              ],
            ),
            if (all.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpace.page),
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              '已导入 ${all.length} 个书源',
                              style: context.text.titleMedium,
                            ),
                          ),
                          GestureDetector(
                            onTap: _checking ? null : _check,
                            child: Row(
                              children: <Widget>[
                                Icon(Icons.refresh,
                                    size: 14,
                                    color: _checking ? p.inkFaint : p.primary),
                                const SizedBox(width: 4),
                                Text(
                                  _checking
                                      ? '检测中 $_checked/$_toCheck'
                                      : '重新检测',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        _checking ? p.inkFaint : p.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('$ok 个可用 · $bad 个失效 · $idle 个未测',
                          style: context.text.bodySmall),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: AppRadius.rPill,
                        child: Row(
                          children: <Widget>[
                            if (ok > 0)
                              Expanded(
                                flex: ok,
                                child: Container(height: 6, color: p.primary),
                              ),
                            if (bad > 0)
                              Expanded(
                                flex: bad,
                                child: Container(height: 6, color: p.bad),
                              ),
                            if (idle > 0)
                              Expanded(
                                flex: idle,
                                child:
                                    Container(height: 6, color: p.surfaceAlt),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.page, AppSpace.md, AppSpace.page, AppSpace.sm),
              child: TextField(
                controller: _query,
                onChanged: (_) => setState(() {}),
                style: TextStyle(fontSize: 15, color: p.ink),
                decoration: InputDecoration(
                  hintText: '搜索源名或域名',
                  prefixIcon: Icon(Icons.search, size: 20, color: p.inkMid),
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpace.page),
              child: Row(
                children: <Widget>[
                  for (final List<String> c in <List<String>>[
                    <String>['all', '全部'],
                    <String>['ok', '可用'],
                    <String>['bad', '失效'],
                    <String>['idle', '未测'],
                  ]) ...<Widget>[
                    AppChip(
                      label: c[1],
                      selected: _filter == c[0],
                      onTap: () => setState(() => _filter = c[0]),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? EmptyHint(
                      icon: Icons.layers_outlined,
                      title: all.isEmpty ? '还没有书源' : '没有符合条件的书源',
                      subtitle: all.isEmpty
                          ? '这个 App 本身不带内容，需要导入书源规则。\n支持 Legado（阅读 3.0）格式的书源 JSON。'
                          : '换个关键词或筛选条件',
                      action: all.isEmpty
                          ? FilledButton.icon(
                              onPressed: _openPasteDialog,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('粘贴导入书源'),
                            )
                          : null,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(0, AppSpace.sm, 0, 96),
                      itemCount: list.length,
                      separatorBuilder: (BuildContext c, int i) => Divider(
                        height: 1,
                        thickness: 1,
                        color: p.line,
                        indent: 76,
                      ),
                      itemBuilder: (BuildContext context, int i) =>
                          FadeSlideIn(
                        index: i,
                        rise: 8,
                        child: _SourceRow(
                          source: list[i],
                          health: _health[list[i].url],
                          onOpen: () => _showActions(list[i]),
                          onToggle: (bool v) => context
                              .read<AppState>()
                              .setSourceEnabled(list[i], v),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showImportMenu() async {
    final String? v = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('粘贴导入'),
              onTap: () => Navigator.of(c).pop('paste'),
            ),
            ListTile(
              leading: const Icon(Icons.content_paste),
              title: const Text('从剪贴板导入'),
              onTap: () => Navigator.of(c).pop('clip'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('从文件导入'),
              onTap: () => Navigator.of(c).pop('file'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_all),
              title: const Text('导出到剪贴板'),
              onTap: () => Navigator.of(c).pop('export'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (v == null || !mounted) return;
    switch (v) {
      case 'paste':
        await _openPasteDialog();
      case 'clip':
        await _importFromClipboard();
      case 'file':
        await _importFromFile();
      case 'export':
        await _export();
    }
  }

  Future<void> _showBatchMenu() async {
    final AppState state = context.read<AppState>();
    final String? v = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.done_all),
              title: const Text('全部启用'),
              onTap: () => Navigator.of(c).pop('on'),
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('全部停用'),
              onTap: () => Navigator.of(c).pop('off'),
            ),
            ListTile(
              leading: Icon(Icons.delete_sweep_outlined,
                  color: context.palette.bad),
              title: Text('删除全部书源',
                  style: TextStyle(color: context.palette.bad)),
              onTap: () => Navigator.of(c).pop('del'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (v == null || !mounted) return;
    if (v == 'on' || v == 'off') {
      for (final BookSource s in state.sources) {
        await state.setSourceEnabled(s, v == 'on');
      }
      _toast(v == 'on' ? '已全部启用' : '已全部停用');
    } else if (v == 'del') {
      final bool? ok = await showDialog<bool>(
        context: context,
        builder: (BuildContext c) => AlertDialog(
          title: const Text('删除全部书源'),
          content: Text('确定删除全部 ${state.sources.length} 个书源吗？'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      if (ok == true) {
        await state.deleteSources(
            state.sources.map((BookSource s) => s.url).toList());
        _toast('已全部删除');
      }
    }
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Icon(icon, size: 22, color: context.palette.ink),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.source,
    required this.health,
    required this.onOpen,
    required this.onToggle,
  });

  final BookSource source;
  final bool? health;
  final VoidCallback onOpen;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;
    final Color dot = health == null
        ? p.idle
        : (health! ? p.ok : p.bad);
    final String label =
        health == null ? '未测' : (health! ? '可用' : '失效');
    final String host = Uri.tryParse(source.url)?.host ?? source.url;

    return InkWell(
      onLongPress: onOpen,
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.page, 10, AppSpace.page - 4, 10),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.surfaceAlt,
                borderRadius: AppRadius.rSm,
              ),
              child: Text(
                source.name.isEmpty
                    ? '?'
                    : source.name.characters.first.toUpperCase(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: p.primaryDeep,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          source.name.isEmpty ? '(未命名)' : source.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleMedium,
                        ),
                      ),
                      if (source.isComic) ...<Widget>[
                        const SizedBox(width: 6),
                        SourceTag('漫画', type: 1),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    host,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            Row(
              children: <Widget>[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(fontSize: 11, color: p.inkMid)),
              ],
            ),
            const SizedBox(width: 6),
            Transform.scale(
              scale: 0.8,
              child: Switch(value: source.enabled, onChanged: onToggle),
            ),
          ],
        ),
      ),
    );
  }
}
