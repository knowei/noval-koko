import 'package:flutter/material.dart';

import '../ui/theme/app_theme.dart';
import 'motion.dart';

class NavItem {
  const NavItem(this.icon, this.activeIcon, this.label);

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// 底部导航：选中项是一个墨绿胶囊，里面白图标 + 白字。
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.index,
    required this.onTap,
    this.items = const <NavItem>[
      NavItem(Icons.auto_stories_outlined, Icons.auto_stories, '书架'),
      NavItem(Icons.search_outlined, Icons.search, '搜索'),
      NavItem(Icons.person_outline, Icons.person, '我的'),
    ],
  });

  final int index;
  final ValueChanged<int> onTap;
  final List<NavItem> items;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: <Widget>[
              for (int i = 0; i < items.length; i++)
                Expanded(
                  child: Center(
                    child: _NavButton(
                      item: items[i],
                      selected: i == index,
                      onTap: () => onTap(i),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = context.palette;

    return TapScale(
      onTap: onTap,
      scale: 0.93,
      child: AnimatedSwitcher(
        duration: kMotionMid,
        switchInCurve: kMotionCurve,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (Widget c, Animation<double> a) => FadeTransition(
          opacity: a,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1).animate(
              CurvedAnimation(parent: a, curve: kMotionCurve),
            ),
            child: c,
          ),
        ),
        child: selected ? _pill(p) : _plain(p),
      ),
    );
  }

  Widget _pill(AppPalette p) {
    return DecoratedBox(
      key: const ValueKey<String>('on'),
      decoration: BoxDecoration(
        color: p.primary,
        borderRadius: AppRadius.rPill,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(item.activeIcon, size: 19, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              item.label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _plain(AppPalette p) {
    return Padding(
      key: const ValueKey<String>('off'),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(item.icon, size: 21, color: p.inkMid),
          const SizedBox(height: 3),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 11,
              height: 1.1,
              color: p.inkMid,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}
