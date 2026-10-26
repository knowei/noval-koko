import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'ui/home_page.dart';
import 'ui/mine_page.dart';
import 'ui/nav_bar.dart';
import 'ui/search_page.dart';
import 'ui/theme/app_theme.dart';

/// 墨町 —— 自用的规则驱动小说 / 漫画阅读器。
class MotingApp extends StatelessWidget {
  const MotingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>(
      create: (_) => AppState()..bootstrap(),
      child: Consumer<AppState>(
        builder: (BuildContext context, AppState state, Widget? _) {
          return MaterialApp(
            title: '墨町',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(state.theme, Brightness.light),
            darkTheme: buildAppTheme(state.theme, Brightness.dark),
            themeMode: ThemeMode.light,
            // 桌面端默认不允许鼠标拖动滚动，导致「下拉刷新」这种手势在
            // Windows 上根本触发不了。这里显式放开鼠标/触控板拖拽。
            scrollBehavior: const _DragScrollBehavior(),
            home: const RootPage(),
          );
        },
      ),
    );
  }
}

/// 让鼠标/触控板也能拖动滚动（桌面端默认只有触摸能拖）。
/// 没有这个，Windows 上的「下拉刷新」用手势永远触发不了。
class _DragScrollBehavior extends MaterialScrollBehavior {
  const _DragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();

    if (!state.ready) {
      return Scaffold(
        body: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.palette.primary,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const <Widget>[
          HomePage(),
          SearchPage(),
          MinePage(),
        ],
      ),
      bottomNavigationBar: AppNavBar(
        index: _index,
        onTap: (int i) => setState(() => _index = i),
      ),
    );
  }
}
