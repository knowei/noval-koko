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

    test('version.dart 与当前包版本一致', () {
      expect(kAppVersion, '0.2.0');
      expect(kAppBuildNumber, greaterThanOrEqualTo(1));
    });
  });
}
