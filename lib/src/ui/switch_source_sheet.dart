import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../model/shelf_book.dart';

/// 换源面板：边搜边列出「其它源里的同一本书」，点一条就切过去。
class SwitchSourceSheet extends StatefulWidget {
  const SwitchSourceSheet({super.key, required this.book});

  final ShelfBook book;

  @override
  State<SwitchSourceSheet> createState() => _SwitchSourceSheetState();
}

class _SwitchSourceSheetState extends State<SwitchSourceSheet> {
  final List<SourceCandidate> _list = <SourceCandidate>[];
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final AppState state = context.read<AppState>();
    await state.findSourcesFor(
      widget.book,
      onCandidate: (SourceCandidate c) {
        if (!mounted) return;
        setState(() => _list.add(c));
      },
    );
    if (mounted) setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
              child: Row(
                children: <Widget>[
                  Icon(Icons.swap_horiz, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('换个源', style: theme.textTheme.titleMedium),
                        Text(
                          '《${widget.book.name}》· 当前源 ${widget.book.sourceName.isEmpty ? '未知' : widget.book.sourceName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                  if (!_done)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: _list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                      child: Text(
                        _done
                            ? '其它源里没找到同名的书。可以把书名缩短一点再搜，或者去书源页加个源。'
                            : '正在逐个源里找…',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: _list.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (BuildContext ctx, int i) {
                        final SourceCandidate c = _list[i];
                        return ListTile(
                          title: Text(
                            c.book.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            <String>[
                              if (c.book.author.isNotEmpty) c.book.author,
                              if (c.book.lastChapter.isNotEmpty)
                                '最新 ${c.book.lastChapter}',
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              c.source.name,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          onTap: () => Navigator.of(context).pop(c),
                        );
                      },
                    ),
            ),
            if (_list.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

