import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// 域名 → 真实 IP 的覆盖表。
///
/// 为什么需要它（2026-10-27 实测）：国内 DNS 对这些站返回的是**伪造 IP**
/// （`18comic.vip` 被解析到 Facebook 的 157.240.8.41、`www.picacomic.com` 到
/// 128.121.243.77），所以纯 HTTP 客户端怎么重试都只会超时——真正被墙的是
/// **DNS 解析**，不是 IP 或 SNI。一旦拿到真 IP，直连 Cloudflare 是完全通的：
///
/// ```
/// 18comic.vip       172.66.162.116  -> HTTP 403（CF 人机验证，站点是活的）
/// www.picacomic.com 172.66.173.71  -> HTTP 200
/// ```
///
/// 这也是同类阅读器（Venera-Next）「禁漫不开代理」的做法：它的 HTTP 层是 Rust
/// reqwest，带 `DnsSettings::StaticDns/DynamicDns`（设置里叫「DNS 覆盖」），
/// 绕开系统解析器即可。我们这里用 `HttpClient.connectionFactory` 做同一件事：
/// 连接打到指定 IP，Host 与 TLS SNI 仍是原域名，证书校验照常。
class DnsOverride {
  DnsOverride._();

  /// 内置表。更新方式：改这里，或者放一份 `dns_overrides.json` 到应用数据目录
  /// （见 [loadFromSupportDir]），后者优先。
  static const Map<String, List<String>> builtin = <String, List<String>>{
    '18comic.vip': <String>['172.66.162.116', '104.20.43.122'],
    'www.18comic.vip': <String>['172.66.162.116', '104.20.43.122'],
    'www.picacomic.com': <String>['172.66.173.71', '104.20.42.9'],
    'picacomic.com': <String>['172.66.173.71', '104.20.42.9'],
    // 哔咔的接口与图床跟网页同一组 Cloudflare 地址。
    'picaapi.picacomic.com': <String>['104.20.42.9', '172.66.173.71'],
    'storage1.picacomic.com': <String>['104.20.42.9', '172.66.173.71'],
    'storage2.picacomic.com': <String>['104.20.42.9', '172.66.173.71'],
  };

  static final Map<String, List<String>> _table =
      <String, List<String>>{...builtin};

  static Map<String, List<String>> get all =>
      Map<String, List<String>>.unmodifiable(_table);

  static List<String>? of(String host) {
    final List<String>? byFull = _table[host];
    if (byFull != null && byFull.isNotEmpty) return byFull;
    // 也支持写不带 www 的父域，命中子域。
    final String bare = host.replaceFirst(RegExp(r'^www\.'), '');
    final List<String>? byBare = _table[bare];
    if (byBare != null && byBare.isNotEmpty) return byBare;
    return null;
  }

  static bool has(String host) => of(host) != null;

  /// 合并一份 JSON（`{"host": ["ip1","ip2"]}` 或 `{"host": "ip"}`）。
  static void merge(Map<String, dynamic> json) {
    json.forEach((String host, dynamic v) {
      final List<String> ips = v is String
          ? <String>[v]
          : (v as List<dynamic>).map((dynamic e) => '$e').toList();
      final List<String> clean =
          ips.map((String e) => e.trim()).where((String e) => e.isNotEmpty).toList();
      if (clean.isNotEmpty) _table[host.trim()] = clean;
    });
  }

  /// 读应用数据目录下的 `dns_overrides.json`（存在才读，坏文件不影响启动）。
  static Future<void> loadFromSupportDir(Directory dir) async {
    try {
      final File f = File('${dir.path}${Platform.pathSeparator}dns_overrides.json');
      if (!await f.exists()) return;
      final dynamic decoded = jsonDecode(await f.readAsString());
      if (decoded is Map<String, dynamic>) merge(decoded);
    } catch (e) {
      debugPrint('[noval] dns_overrides.json 读取失败：$e');
    }
  }
}
