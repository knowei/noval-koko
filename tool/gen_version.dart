// 从 pubspec.yaml 的 version: 行生成 lib/src/core/version.dart
// 用法：dart run tool/gen_version.dart
import 'dart:io';

void main() {
  final File pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('找不到 pubspec.yaml，请在项目根目录运行');
    exit(1);
  }
  final RegExp re = RegExp(r'^version:\s*([0-9][0-9A-Za-z.\-]*)\+?(\d+)?',
      multiLine: true);
  final RegExpMatch? m = re.firstMatch(pubspec.readAsStringSync());
  if (m == null) {
    stderr.writeln('pubspec.yaml 里没有 version:');
    exit(1);
  }
  final String version = m.group(1)!;
  final int build = int.tryParse(m.group(2) ?? '') ?? 1;

  final String out = '''
// 由 tool/gen_version.dart 从 pubspec.yaml 生成，请勿手改。
// ignore_for_file: constant_identifier_names

/// 应用版本号（对应 pubspec.yaml 的 `version:` 前半段）。
const String kAppVersion = '$version';

/// 构建号（对应 `version:` 的 `+` 之后）。
const int kAppBuildNumber = $build;
''';
  File('lib/src/core/version.dart').writeAsStringSync(out);
  stdout.writeln('version.dart <- $version+$build');
}
