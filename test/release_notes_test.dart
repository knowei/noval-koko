import 'package:flutter_test/flutter_test.dart';
import 'package:noval/src/core/release_notes.dart';

void main() {
  test('GitHub 自动生成的 notes 被清洗成人话', () {
    const String body = '''
## What's Changed
* feat: 暗色模式 by @knowei in https://github.com/knowei/noval-koko/pull/13
* fix: 阅读进度不同步 by @knowei in https://github.com/knowei/noval-koko/pull/14
- 详情页按钮溢出 by @knowei in https://github.com/knowei/noval-koko/pull/15

**Full Changelog**: https://github.com/knowei/noval-koko/compare/v0.5.0...v0.6.0
''';
    final String out = ReleaseNotes.plain(body);
    expect(out.contains('Full Changelog'), isFalse);
    expect(out.contains('github.com'), isFalse);
    expect(out.contains('@knowei'), isFalse);
    expect(out.contains('##'), isFalse);
    expect(out.contains('`'), isFalse);
    expect(out.contains('· 暗色模式'), isTrue);
    expect(out.contains('· 阅读进度不同步'), isTrue);
    expect(out.contains('· 详情页按钮溢出'), isTrue);
  });

  test('New Contributors 之后的内容全部丢弃', () {
    const String body = '''
· 保留这条

## New Contributors
* @someone made their first contribution in https://github.com/x/y/pull/1
''';
    final String out = ReleaseNotes.plain(body);
    expect(out, '· 保留这条');
  });

  test('空正文给出兜底文案', () {
    expect(ReleaseNotes.plain('   '), '这个版本没有写更新说明。');
    expect(ReleaseNotes.plain('\n\n'), '这个版本没有写更新说明。');
  });

  test('手写的中文说明基本原样保留', () {
    const String body = '''
### 新功能
- 暗色模式：外观里新增「跟随系统 / 浅色 / 深色」
- 更新说明：弹窗会显示这个版本改了什么
''';
    final String out = ReleaseNotes.plain(body);
    expect(out.contains('新功能'), isTrue);
    expect(out.contains('· 暗色模式：外观里新增「跟随系统 / 浅色 / 深色」'), isTrue);
    expect(out.contains('· 更新说明：弹窗会显示这个版本改了什么'), isTrue);
  });
}
