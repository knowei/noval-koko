import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noval/src/core/update_service.dart';
import 'package:noval/src/core/version.dart';

void main() {
  group('版本号比较', () {
    test('新 tag 大于旧版本', () {
      expect(UpdateService.isNewer('v0.3.0', '0.2.0'), isTrue);
      expect(UpdateService.isNewer('0.2.1', '0.2.0'), isTrue);
      expect(UpdateService.isNewer('v1.0.0', '0.9.9'), isTrue);
      expect(UpdateService.isNewer('v0.10.0', '0.9.0'), isTrue);
    });

    test('相同或更旧不算更新', () {
      expect(UpdateService.isNewer('v0.2.0', '0.2.0'), isFalse);
      expect(UpdateService.isNewer('v0.1.0', '0.2.0'), isFalse);
      expect(UpdateService.isNewer('0.2.0+2', '0.2.0'), isFalse);
      expect(UpdateService.isNewer('', '0.2.0'), isFalse);
    });

    // 不再硬编码版本号：直接和 pubspec.yaml 比对，
    // 这样每次发版只改 pubspec + 跑 gen_version 就够，测试不会因为升版本挂掉。
    test('version.dart 与 pubspec.yaml 一致', () {
      final String pubspec = File('pubspec.yaml').readAsStringSync();
      final Match? m = RegExp(
        r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)',
        multiLine: true,
      ).firstMatch(pubspec);
      expect(m, isNotNull, reason: 'pubspec.yaml 里应有 version: x.y.z+n');
      expect(kAppVersion, m!.group(1));
      expect(kAppBuildNumber, int.parse(m.group(2)!));
    });
  });
}
