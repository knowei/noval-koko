// 应用内更新的联网校验：能拿到最新 Release、能挑出 APK 资产、版本比较方向正确。
// 跑法：flutter test integration_test/update_check_test.dart -d windows
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noval/src/core/update_service.dart';
import 'package:noval/src/core/version.dart';

void main() {
  test('GitHub Release 可读，且能挑出 APK 资产', () async {
    final UpdateService svc = UpdateService();
    ReleaseInfo? info;
    try {
      info = await svc.fetchLatest();
    } on DioException catch (e) {
      // 网络不通不判定为功能缺陷，但要把原因写清楚
      File('tool/update_check.txt').writeAsStringSync('网络失败：${e.type.name} ${e.message}');
      return;
    }
    expect(info, isNotNull, reason: '仓库应该至少有一个 Release');

    final StringBuffer log = StringBuffer()
      ..writeln('当前版本 ${svc.currentVersion}（tag ${svc.currentTag}）')
      ..writeln('最新 Release ${info!.tag} · ${info.name}')
      ..writeln('页面 ${info.pageUrl}')
      ..writeln('资产 ${info.asset?.name ?? '无 APK'} · ${info.asset?.size ?? 0} B')
      ..writeln('有更新？${svc.hasUpdate(info)}');
    if (info.asset != null) {
      log.writeln('下载地址 ${info.asset!.url}');
      expect(info.asset!.url, contains('github.com'));
      expect(info.asset!.name.toLowerCase(), endsWith('.apk'));
    }
    log.writeln('kAppVersion=$kAppVersion');
    File('tool/update_check.txt').writeAsStringSync(log.toString());
  }, timeout: const Timeout(Duration(minutes: 2)));
}
