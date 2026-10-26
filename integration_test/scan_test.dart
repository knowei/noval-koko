// 批量体检：从 tool/scan_raw/ 里收集的公开书源集合中筛出「真正能搜到书」的源。
// 跑法：flutter test integration_test/scan_test.dart -d windows
// 报告：tool/scan_report.txt（UTF-8）
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noval/src/model/book_source.dart';
import 'package:noval/src/net/http_service.dart';
import 'package:noval/src/source/source_engine.dart';

const String kKeyword = '剑来';
const Duration kTimeout = Duration(seconds: 6);
const int kHostWorkers = 32;
const int kSourceWorkers = 16;
const int kChainLimit = 150; // 只对前 N 个「搜到了」的源做详情/目录/正文链路验证

class _Src {
  _Src(this.source, this.origin);
  final BookSource source;
  final String origin;
  String get url => source.url;
  String get host => Uri.tryParse(source.url)?.host ?? '';
}

class _Verdict {
  _Verdict(this.kind, this.detail, {this.items = 0, this.chain = ''});
  final String kind; // ok / empty / err / dead-host
  final String detail;
  final int items;
  String chain;
}

Future<T> _withTimeout<T>(Future<T> f) => f.timeout(kTimeout);

/// 从一个 JSON 文件里尽量榨出书源对象。
List<Map<String, dynamic>> _extract(Object? node, [int depth = 0]) {
  final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
  if (depth > 6 || node == null) return out;
  if (node is List) {
    for (final Object? e in node) {
      out.addAll(_extract(e, depth + 1));
    }
    return out;
  }
  if (node is Map<String, dynamic>) {
    if (node['bookSourceUrl'] is String || node['bookSourceName'] is String) {
      out.add(node);
      return out;
    }
    for (final Object? v in node.values) {
      out.addAll(_extract(v, depth + 1));
    }
  }
  return out;
}

Future<void> _runPool<T>(
  List<T> items,
  int workers,
  Future<void> Function(T item) job,
) async {
  int next = 0;
  Future<void> worker() async {
    while (true) {
      final int i = next++;
      if (i >= items.length) return;
      await job(items[i]);
    }
  }

  await Future.wait(List<Future<void>>.generate(workers, (_) => worker()));
}

void main() {
  test('扫描 tool/scan_raw 下的公开书源并体检', () async {
    final Directory dir = Directory('tool/scan_raw');
    expect(dir.existsSync(), isTrue);
    final List<File> files = dir
        .listSync()
        .whereType<File>()
        .where((File f) => f.path.toLowerCase().endsWith('.json'))
        .toList();
    stdout.writeln('files=${files.length}');

    // 1) 解析 + 去重
    final Map<String, _Src> uniq = <String, _Src>{};
    int parseFail = 0;
    for (final File f in files) {
      String text;
      try {
        text = utf8.decode(f.readAsBytesSync(), allowMalformed: true);
      } catch (_) {
        parseFail++;
        continue;
      }
      Object? json;
      try {
        json = jsonDecode(text);
      } catch (_) {
        parseFail++;
        continue;
      }
      for (final Map<String, dynamic> m in _extract(json)) {
        BookSource bs;
        try {
          bs = BookSource.fromJson(m);
        } catch (_) {
          continue;
        }
        if (bs.url.trim().isEmpty) continue;
        if (!bs.enabled) continue;
        if (bs.searchUrl.trim().isEmpty) continue;
        final String key = bs.url.trim();
        uniq.putIfAbsent(key, () => _Src(bs, f.uri.pathSegments.last));
      }
    }
    stdout.writeln(
        'parsed sources unique=${uniq.length} parseFailFiles=$parseFail');

    // 2) 先按域名粗筛（一个域名只探一次，砍掉大量死站）
    final Map<String, List<_Src>> byHost = <String, List<_Src>>{};
    for (final _Src s in uniq.values) {
      byHost.putIfAbsent(s.host.isEmpty ? '?' : s.host, () => <_Src>[]).add(s);
    }
    stdout.writeln('hosts=${byHost.length}');

    final HttpService probe = HttpService(timeout: const Duration(seconds: 5));
    final Set<String> aliveHosts = <String>{};
    final Map<String, String> deadReason = <String, String>{};
    final List<String> hosts = byHost.keys.toList();
    int hostDone = 0;
    await _runPool<String>(hosts, kHostWorkers, (String h) async {
      try {
        final HttpResult r = await _withTimeout(
          probe.request('https://$h/', method: 'GET'),
        );
        if (r.statusCode < 400) {
          aliveHosts.add(h);
        } else {
          deadReason[h] = 'HTTP ${r.statusCode}';
        }
      } catch (e) {
        deadReason[h] = '$e'.replaceAll('\n', ' ').split('：').last;
      }
      hostDone++;
      if (hostDone % 100 == 0) {
        stdout.writeln('  host probe $hostDone/${hosts.length} '
            'alive=${aliveHosts.length}');
      }
    });
    stdout.writeln(
        'hostsAlive=${aliveHosts.length} hostsDead=${deadReason.length}');

    // 3) 对活域名下的源逐个搜索
    final List<_Src> alive = <_Src>[];
    for (final MapEntry<String, List<_Src>> e in byHost.entries) {
      if (aliveHosts.contains(e.key)) alive.addAll(e.value);
    }
    stdout.writeln('aliveHosts sources=${alive.length}');

    final Map<String, _Verdict> verdict = <String, _Verdict>{};
    for (final MapEntry<String, List<_Src>> e in byHost.entries) {
      if (!aliveHosts.contains(e.key)) {
        for (final _Src s in e.value) {
          verdict[s.url] =
              _Verdict('dead-host', deadReason[e.key] ?? '域名不可达');
        }
      }
    }

    int done = 0;
    await _runPool<_Src>(alive, kSourceWorkers, (_Src s) async {
      final SourceEngine engine = SourceEngine(
        http: HttpService(timeout: kTimeout),
      );
      try {
        final List<dynamic> hits =
            await _withTimeout(engine.search(s.source, kKeyword));
        verdict[s.url] = hits.isEmpty
            ? _Verdict('empty', '搜索 0 条')
            : _Verdict('ok', '', items: hits.length, chain: 'search');
      } catch (e) {
        verdict[s.url] =
            _Verdict('err', '$e'.replaceAll('\n', ' ').split('：').last);
      } finally {
        done++;
        if (done % 25 == 0) {
          final int ok = verdict.values.where((_Verdict v) => v.kind == 'ok').length;
          stdout.writeln('  scan $done/${alive.length} ok=$ok');
        }
      }
    });

    // 4) 对搜到的源验证 详情 → 目录 → 正文
    final List<_Src> okSources = uniq.values
        .where((_Src s) => verdict[s.url]?.kind == 'ok')
        .take(kChainLimit)
        .toList();
    stdout.writeln('chain candidates=${okSources.length}');
    int chainDone = 0;
    await _runPool<_Src>(okSources, 8, (_Src s) async {
      final SourceEngine engine = SourceEngine(
        http: HttpService(timeout: kTimeout),
      );
      final List<String> steps = <String>[];
      try {
        final List<dynamic> hits =
            await _withTimeout(engine.search(s.source, kKeyword));
        final dynamic first = hits.first;
        final String bookUrl = first.bookUrl as String;
        steps.add('search=${hits.length}');
        final dynamic info = await _withTimeout(
          engine.bookInfo(s.source, bookUrl),
        );
        steps.add('info');
        final List<dynamic> chs = await _withTimeout(
          engine.chapters(s.source, info, maxPages: 2),
        );
        steps.add('toc=${chs.length}');
        if (chs.isNotEmpty) {
          final dynamic ch = chs[chs.length ~/ 2];
          final dynamic ct = await _withTimeout(
            engine.content(s.source, ch),
          );
          final int len = (ct.text as String).length;
          steps.add('text=$len');
          if (len < 50) steps.add('THIN');
        }
        verdict[s.url]!.chain = steps.join(',');
      } catch (e) {
        steps.add('FAIL:${'$e'.split('：').last}');
        verdict[s.url]!.chain = steps.join(',');
      } finally {
        chainDone++;
        if (chainDone % 10 == 0) {
          stdout.writeln('  chain $chainDone/${okSources.length}');
        }
      }
    });

    // 5) 出报告
    final List<_Src> ordered = uniq.values.toList()
      ..sort((_Src a, _Src b) {
        final int ka = _rank(verdict[a.url]);
        final int kb = _rank(verdict[b.url]);
        if (ka != kb) return ka.compareTo(kb);
        return (verdict[b.url]?.items ?? 0).compareTo(verdict[a.url]?.items ?? 0);
      });

    final StringBuffer sb = StringBuffer();
    int ok = 0, empty = 0, err = 0, deadHost = 0;
    for (final _Src s in uniq.values) {
      switch (verdict[s.url]?.kind ?? 'err') {
        case 'ok':
          ok++;
        case 'empty':
          empty++;
        case 'dead-host':
          deadHost++;
        default:
          err++;
      }
    }
    sb.writeln('# 书源体检报告 ${DateTime.now()}');
    sb.writeln('关键词=$kKeyword 文件=${files.length} 去重源=${uniq.length} '
        '域名=${byHost.length} 活域名=${aliveHosts.length}');
    sb.writeln('可用(搜到书)=$ok 搜不到=$empty 报错=$err 域名不通=$deadHost');
    sb.writeln('');
    sb.writeln('## 搜到书的源');
    for (final _Src s in ordered) {
      final _Verdict? v = verdict[s.url];
      if (v?.kind != 'ok') continue;
      sb.writeln('- [${v!.items}] ${s.source.name} | ${s.url} | chain=${v.chain}');
    }
    sb.writeln('');
    sb.writeln('## 搜不到（域名活着）');
    for (final _Src s in ordered) {
      final _Verdict? v = verdict[s.url];
      if (v?.kind != 'empty') continue;
      sb.writeln('- ${s.source.name} | ${s.url} | ${v!.detail}');
    }
    sb.writeln('');
    sb.writeln('## 报错');
    for (final _Src s in ordered) {
      final _Verdict? v = verdict[s.url];
      if (v?.kind != 'err') continue;
      sb.writeln('- ${s.source.name} | ${s.url} | ${v!.detail}');
    }
    File('tool/scan_report.txt').writeAsStringSync(sb.toString());

    stdout.writeln('=== ok=$ok empty=$empty err=$err deadHost=$deadHost ===');
    for (final _Src s in ordered.where((_Src s) => verdict[s.url]?.kind == 'ok')) {
      stdout.writeln('OK ${verdict[s.url]!.items} ${s.host} '
          '[${verdict[s.url]!.chain}] ${s.source.name}');
    }
    expect(uniq.isNotEmpty, isTrue);
  }, timeout: const Timeout(Duration(minutes: 90)));
}

int _rank(_Verdict? v) {
  switch (v?.kind) {
    case 'ok':
      return 0;
    case 'empty':
      return 1;
    case 'err':
      return 2;
    default:
      return 3;
  }
}
