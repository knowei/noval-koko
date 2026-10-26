import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import 'app_theme.dart';

/// 底部弹出的主题选择器；选中后立即写入 AppState（本地持久化）。
Future<void> showThemeSheet(BuildContext context) async {
  final AppState state = context.read<AppState>();
  final String? id = await showModalBottomSheet<String>(
    context: context,
    builder: (BuildContext c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.page, AppSpace.lg, AppSpace.page, AppSpace.sm),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('选择主题', style: c.text.titleMedium),
            ),
          ),
          for (final AppTheme t in kAppThemes)
            ListTile(
              leading: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: t.light.bg,
                  borderRadius: AppRadius.rSm,
                  border: Border.all(color: t.light.primary, width: 2),
                ),
              ),
              title: Text(t.label),
              trailing: t.id == state.themeId
                  ? Icon(Icons.check, color: c.palette.primary)
                  : null,
              onTap: () => Navigator.of(c).pop(t.id),
            ),
          const SizedBox(height: AppSpace.md),
        ],
      ),
    ),
  );
  if (id != null) await state.setTheme(id);
}
