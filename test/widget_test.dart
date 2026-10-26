import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:noval/src/ui/theme/app_theme.dart';

void main() {
  test('每套主题都能构建出 Material 3 的 ThemeData', () {
    for (final AppTheme t in kAppThemes) {
      final ThemeData light = buildAppTheme(t, Brightness.light);
      expect(light.useMaterial3, isTrue);
      expect(light.extension<AppPalette>(), isNotNull);
      expect(light.scaffoldBackgroundColor, t.light.bg);
      expect(buildAppTheme(t, Brightness.dark).brightness, Brightness.dark);
    }
  });
}
