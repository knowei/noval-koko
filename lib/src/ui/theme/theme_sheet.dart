import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import 'app_theme.dart';

/// 底部弹出的主题选择器：外观模式（跟随系统/浅色/深色）+ 主题色。
/// 选中后立即写入 AppState（本地持久化）。
Future<void> showThemeSheet(BuildContext context) async {
  final AppState state = context.read<AppState>();
  String mode = state.themeModeId;

  final String? id = await showModalBottomSheet<String>(
    context: context,
    builder: (BuildContext c) => StatefulBuilder(
      builder: (BuildContext c, StateSetter setSheet) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.page, AppSpace.lg, AppSpace.page, AppSpace.sm),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('外观', style: c.text.titleMedium),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
                  child: Wrap(
                    spacing: AppSpace.sm,
                    runSpacing: AppSpace.sm,
                    children: <Widget>[
                      _ModeChip(
                        label: '跟随系统',
                        icon: Icons.brightness_auto_outlined,
                        selected: mode == 'system',
                        onTap: () async {
                          setSheet(() => mode = 'system');
                          await state.setThemeMode('system');
                        },
                      ),
                      _ModeChip(
                        label: '浅色',
                        icon: Icons.light_mode_outlined,
                        selected: mode == 'light',
                        onTap: () async {
                          setSheet(() => mode = 'light');
                          await state.setThemeMode('light');
                        },
                      ),
                      _ModeChip(
                        label: '深色',
                        icon: Icons.dark_mode_outlined,
                        selected: mode == 'dark',
                        onTap: () async {
                          setSheet(() => mode = 'dark');
                          await state.setThemeMode('dark');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
                  child: Text('主题色', style: c.text.titleMedium),
                ),
                const SizedBox(height: AppSpace.xs),
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
      },
    ),
  );
  if (id != null) await state.setTheme(id);
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: Icon(
        icon,
        size: 18,
        color: selected ? context.palette.primaryDeep : context.palette.inkMid,
      ),
      label: Text(label),
      showCheckmark: false,
      selectedColor: context.palette.surfaceAlt,
      labelStyle: TextStyle(
        color: selected ? context.palette.primaryDeep : context.palette.inkMid,
        fontSize: 13,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
      side: BorderSide(
        color: selected ? context.palette.primary : context.palette.line,
      ),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.rPill),
    );
  }
}
