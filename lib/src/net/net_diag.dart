import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../core/text_util.dart';

/// 一次域名探测的结果。
class HostProbe {
  const HostProbe({
    required this.host,
    this.ips = const <String>[],
    this.ms,
    this.status,
    this.error = '',
  });

  final String host;

  /// DNS 解析到的 IP（空 = 解析失败）。
  final List<String> ips;

  /// 建连 + 拿到响应头的耗时。
  final int? ms;

  /// HTTP 状态码。
  final int? status;

  /// 失败原因（空 = 没失败）。
  final String error;

  bool get dnsOk => ips.isNotEmpty;

  bool get ok => dnsOk && error.isEmpty;

  /// 一句话结论，给界面直接用。
  String get label {
    if (!dnsOk) return error.isEmpty ? 'DNS 解析失败' : error;
    if (error.isNotEmpty) return error;
    final String code = status == null ? '' : 'HTTP $status';
    final String rtt = ms == null ? '' : '$ms ms';
    return <String>[code, rtt].where((String s) => s.isNotEmpty).join(' · ');
  }
}

/// 网络诊断：把一个书源用到的域名逐个探一遍。
///
/// 存在的意义：规则成立但取不到数据时，先分清是「规则写错」还是
/// 「这个域名在他的网络里根本不通」——后者再改规则也没用。
class NetDiag {
  NetDiag._();

  static final RegExp _urlRe = RegExp(r'https?://([A-Za-z0-9._\-]+)');

  /// 从任意文本（书源 JSON、规则表达式）里抽域名，去重排序。
  static List<String> hostsOf(Iterable<String> texts) {
    final Set<String> out = <String>{};
    for (final String text in texts) {
      for (final Match m in _urlRe.allMatches(text)) {
        final String host = m.group(1)!.toLowerCase();
        if (host.isEmpty) continue;
        // 规则里的占位 / 本地假站点，没必要探
        if (host == 'localhost' || host.startsWith('127.') ||
            host == 'example.com' || host.endsWith('.example.com')) {
          continue;
        }
        out.add(host);
      }
    }
    final List<String> list = out.toList()..sort();
    return list;
  }

  /// 探一个域名：先 DNS，再 GET 首页看能否拿到响应。
  static Future<HostProbe> probe(
    String host, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    List<String> ips = <String>[];
    try {
      final List<InternetAddress> addrs =
          await InternetAddress.lookup(host).timeout(timeout);
      ips = addrs
          .map((InternetAddress a) => a.address)
          .where((String a) => a.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
    } on Object catch (e) {
      return HostProbe(host: host, error: _dnsError(e));
    }
    if (ips.isEmpty) {
      return HostProbe(host: host, error: 'DNS 解析失败');
    }

    final Stopwatch sw = Stopwatch()..start();
    final Dio dio = Dio(
      BaseOptions(
        connectTimeout: timeout,
        receiveTimeout: timeout,
        sendTimeout: timeout,
        followRedirects: true,
        maxRedirects: 6,
        validateStatus: (int? _) => true,
        headers: <String, dynamic>{
          'User-Agent': TextUtil.userAgent,
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        },
      ),
    );
    try {
      final Response<dynamic> r = await dio.get<dynamic>('https://$host/');
      sw.stop();
      return HostProbe(
        host: host,
        ips: ips,
        ms: sw.elapsedMilliseconds,
        status: r.statusCode,
      );
    } on Object catch (e) {
      sw.stop();
      return HostProbe(
        host: host,
        ips: ips,
        ms: sw.elapsedMilliseconds,
        error: _httpError(e, timeout),
      );
    } finally {
      dio.close(force: true);
    }
  }

  /// 并发探测一批域名，每有结果就回调一次（界面可以边探边刷）。
  static Future<List<HostProbe>> probeAll(
    Iterable<String> hosts, {
    Duration timeout = const Duration(seconds: 8),
    void Function(HostProbe probe)? onEach,
    int concurrency = 4,
  }) async {
    final List<String> list = hosts.toList();
    final List<HostProbe?> slots = List<HostProbe?>.filled(list.length, null);
    int next = 0;
    Future<void> worker() async {
      while (true) {
        final int i = next++;
        if (i >= list.length) return;
        final HostProbe p = await probe(list[i], timeout: timeout);
        slots[i] = p;
        onEach?.call(p);
      }
    }

    final int n = concurrency < 1 ? 1 : concurrency;
    await Future.wait<void>(<Future<void>>[
      for (int i = 0; i < n && i < list.length; i++) worker(),
    ]);
    return slots
        .where((HostProbe? p) => p != null)
        .map((HostProbe? p) => p!)
        .toList();
  }

  /// 纯文本报告，方便复制出来贴给我。
  static String report(
    List<HostProbe> probes, {
    String title = '',
    String note = '',
  }) {
    final int okCount = probes.where((HostProbe p) => p.ok).length;
    final StringBuffer sb = StringBuffer();
    if (title.isNotEmpty) sb.writeln('# $title');
    sb.writeln('可用 ${probes.where((HostProbe p) => p.ok).length}/'
        '${probes.length}'
        '${okCount == probes.length ? '' : '（有域名不通）'}');
    if (note.isNotEmpty) sb.writeln(note);
    sb.writeln();
    for (final HostProbe p in probes) {
      final String mark = p.ok ? '✓' : '✗';
      final String ips = p.ips.isEmpty ? '-' : p.ips.join(',');
      sb.writeln('$mark ${p.host.padRight(28)} ${p.label}  [$ips]');
    }
    return sb.toString();
  }

  static String _dnsError(Object e) {
    if (e is TimeoutException) return 'DNS 解析超时（域名可能被污染）';
    if (e is SocketException) return 'DNS 解析失败（域名不存在或解析被拦截）';
    return 'DNS 解析失败：${_short(e)}';
  }

  static String _httpError(Object e, Duration timeout) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          return 'TCP 连接超时（${timeout.inSeconds}s：域名可能被墙）';
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return '读响应超时（${timeout.inSeconds}s：连上了但没数据，可能被限速/阻断）';
        case DioExceptionType.connectionError:
          final String m = '${e.error ?? e.message ?? ''}';
          if (m.contains('reset') || m.contains('10054')) {
            return '连接被重置（典型的网络阻断）';
          }
          return '连接失败（无法建连，域名可能被墙）';
        case DioExceptionType.badCertificate:
          return '证书错误（可能被中间人劫持）';
        case DioExceptionType.cancel:
          return '已取消';
        case DioExceptionType.badResponse:
          return 'HTTP ${e.response?.statusCode ?? '?'}';
        case DioExceptionType.unknown:
          final String m = '${e.error ?? e.message ?? ''}';
          if (m.contains('reset') || m.contains('10054')) {
            return '连接被重置（典型的网络阻断）';
          }
          if (m.contains('lookup') || m.contains('Failed host lookup')) {
            return 'DNS 解析失败';
          }
          return '请求失败：${_short(e)}';
        default:
          return '请求失败：${_short(e)}';
      }
    }
    return '请求失败：${_short(e)}';
  }

  static String _short(Object e) {
    final String s = '$e'.replaceAll(RegExp(r'\s+'), ' ');
    return s.length <= 70 ? s : '${s.substring(0, 70)}…';
  }
}
