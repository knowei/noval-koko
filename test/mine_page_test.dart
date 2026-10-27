import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:noval/src/app_state.dart';
import 'package:noval/src/model/book_source.dart';
import 'package:noval/src/ui/mine_page.dart';
import 'package:noval/src/ui/theme/app_theme.dart';

void main() {
  testWidgets('「我的」页能渲染书源管理/主题/关于三个入口', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final AppState state = AppState();
    state.sources = <BookSource>[
      BookSource.fromJson(<String, dynamic>{
        'bookSourceName': '测试源',
        'bookSourceUrl': 'https://example.com',
      }),
    ];

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: buildAppTheme(kMotimg, Brightness.light),
          home: const Scaffold(body: MinePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('我的'), findsOneWidget);
    expect(find.text('书源管理'), findsOneWidget);
    expect(find.text('主题'), findsOneWidget);
    expect(find.text('关于墨町'), findsOneWidget);
    // 概览里的书源数量应当跟上 state
    expect(find.text('1'), findsWidgets);

    // 主题面板能弹出：外观模式（跟随系统/浅色/深色）+ 主题色
    await tester.tap(find.text('主题'));
    await tester.pumpAndSettle();
    expect(find.text('外观'), findsWidgets);
    expect(find.text('跟随系统'), findsOneWidget);
    expect(find.text('浅色'), findsOneWidget);
    expect(find.text('深色'), findsOneWidget);
    for (final AppTheme t in kAppThemes) {
      expect(find.text(t.label), findsWidgets);
    }
  });
}
