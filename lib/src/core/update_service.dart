import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'version.dart';

/// GitHub Release 的一条资产（这里只关心 APK）。
class ReleaseAsset {
  const ReleaseAsset({required this.name, required this.url, required this.size});

  final String name;
  final String url;
  final int size;
}

/// 一次「检查更新」拿到的结果。
class ReleaseInfo {
  const ReleaseInfo({
    required this.tag,
    required this.name,
    required this.body,
    required this.pageUrl,
    required this.asset,
  });

  final String tag;
  final String name;
  final String body;
  final String pageUrl;

  /// 挑出来的 APK 资产；没有 APK 时为 null（比如只有 Windows 包）。
  final ReleaseAsset? asset;

  String get version => tag.startsWith('v') ? tag.substring(1) : tag;
}

/// 应用内更新：查 GitHub Release → 下 APK → 拉起系统安装。
///
/// 仓库固定为 [owner]/[repo]；Release 由 `.github/workflows/release.yml` 在打 tag 时产出，
/// 资产名形如 `noval-v0.2.0-arm64-v8a.apk`。
class UpdateService {
  UpdateService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 60),
              headers: <String, String>{
                'User-Agent': 'noval/$kAppVersion',
                'Accept': 'application/vnd.github+json',
              },
            ));

  static const String owner = 'knowei';
  static const String repo = 'noval-koko';
  static const String _apiLatest =
      'https://api.github.com/repos/$owner/$repo/releases/latest';

  /// APK 资产的优先级：先 arm64，其次 v7a，最后通用包。
  static const List<String> _preferred = <String>[
    'arm64-v8a',
    'armeabi-v7a',
    'universal',
  ];

  static const MethodChannel _channel = MethodChannel('noval/update');

  final Dio _dio;

  /// 当前版本（来自生成的 version.dart）。
  String get currentVersion => kAppVersion;

  String get currentTag => 'v$kAppVersion';

  /// 查最新 Release；网络失败返回 null（UI 只提示「检查失败」）。
  Future<ReleaseInfo?> fetchLatest() async {
    final Response<dynamic> resp = await _dio.get<dynamic>(
      _apiLatest,
      options: Options(responseType: ResponseType.json),
    );
    final Object? data = resp.data;
    if (data is! Map) return null;
    final Map<String, dynamic> m = data.cast<String, dynamic>();
    final String tag = (m['tag_name'] as String?) ?? '';
    if (tag.isEmpty) return null;
    final List<dynamic> assets =
        (m['assets'] as List<dynamic>?) ?? const <dynamic>[];
    final List<ReleaseAsset> apks = <ReleaseAsset>[];
    for (final dynamic a in assets) {
      if (a is! Map) continue;
      final String name = (a['name'] as String?) ?? '';
      final String url = (a['browser_download_url'] as String?) ?? '';
      if (!name.toLowerCase().endsWith('.apk') || url.isEmpty) continue;
      apks.add(ReleaseAsset(
        name: name,
        url: url,
        size: (a['size'] as num?)?.toInt() ?? 0,
      ));
    }
    apks.sort((ReleaseAsset a, ReleaseAsset b) {
      int rank(ReleaseAsset x) {
        for (int i = 0; i < _preferred.length; i++) {
          if (x.name.contains(_preferred[i])) return i;
        }
        return _preferred.length;
      }

      return rank(a).compareTo(rank(b));
    });
    return ReleaseInfo(
      tag: tag,
      name: (m['name'] as String?) ?? tag,
      body: (m['body'] as String?) ?? '',
      pageUrl: (m['html_url'] as String?) ?? 'https://github.com/$owner/$repo/releases',
      asset: apks.isEmpty ? null : apks.first,
    );
  }

  /// 语义化版本比较：`v0.2.0` vs `0.1.0+1` 这类都能吃。
  static bool isNewer(String latest, String current) {
    List<int> parts(String s) {
      final String clean = s.replaceAll(RegExp(r'^[vV]'), '').split('+').first;
      return clean
          .split(RegExp(r'[.\-]'))
          .map((String e) => int.tryParse(e.replaceAll(RegExp(r'\D'), '')) ?? 0)
          .toList();
    }

    final List<int> a = parts(latest);
    final List<int> b = parts(current);
    for (int i = 0; i < (a.length > b.length ? a.length : b.length); i++) {
      final int x = i < a.length ? a[i] : 0;
      final int y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  /// 新版本是否可用。
  bool hasUpdate(ReleaseInfo info) => isNewer(info.tag, kAppVersion);

  /// 下载 APK 到应用支持目录，返回文件。`onProgress` 会拿到 (已收字节, 总字节)。
  Future<File> download(
    ReleaseInfo info, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final ReleaseAsset? asset = info.asset;
    if (asset == null) {
      throw StateError('这个 Release 没有 APK 资产');
    }
    final Directory base = await getApplicationSupportDirectory();
    final Directory dir = Directory('${base.path}/updates');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final String safeName =
        asset.name.replaceAll(RegExp(r'[^0-9A-Za-z._-]'), '_');
    final File out = File('${dir.path}/$safeName');
    if (out.existsSync()) out.deleteSync();

    await _dio.download(
      asset.url,
      out.path,
      cancelToken: cancelToken,
      onReceiveProgress: onProgress,
      options: Options(
        headers: <String, String>{
          'Accept': 'application/octet-stream',
          'User-Agent': 'noval/$kAppVersion',
        },
      ),
    );
    return out;
  }

  /// 拉起安装：Android 走系统安装器（必须有 [apk]）；桌面端打开 Release 页面。
  Future<String> install(ReleaseInfo info, {File? apk}) async {
    if (Platform.isAndroid) {
      if (apk == null) return '没有下载到 APK';
      final String? r = await _channel.invokeMethod<String>(
        'installApk',
        <String, dynamic>{'path': apk.path},
      );
      return r ?? '已发起安装';
    }
    if (Platform.isWindows) {
      await Process.run('explorer', <String>[info.pageUrl]);
      return '已打开 Release 页面，请手动下载安装';
    }
    if (Platform.isMacOS) {
      await Process.run('open', <String>[info.pageUrl]);
      return '已打开 Release 页面，请手动下载安装';
    }
    if (Platform.isLinux) {
      await Process.run('xdg-open', <String>[info.pageUrl]);
      return '已打开 Release 页面，请手动下载安装';
    }
    return '当前平台不支持自动安装';
  }

  /// 供调试：把 Release 的 JSON 摘要打成一行字符串。
  static String describe(ReleaseInfo info) {
    final ReleaseAsset? a = info.asset;
    final String size = a == null
        ? '无 APK'
        : '${(a.size / 1024 / 1024).toStringAsFixed(1)}MB';
    return '${info.tag} · ${info.name} · $size';
  }

  static String prettyJson(Object? o) =>
      const JsonEncoder.withIndent('  ').convert(o);
}
