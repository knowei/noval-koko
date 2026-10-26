// 从体检报告里挑出「全文链路真的能跑」的源，落成 docs/live_sources.json 并做回归断言。
// 跑法：flutter test integration_test/pick_live_test.dart -d windows
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noval/src/model/book_source.dart';
import 'package:noval/src/model/book_info.dart';
import 'package:noval/src/net/http_service.dart';
import 'package:noval/src/source/source_engine.dart';

const String kKeyword = '剑来';
const Duration kTimeout = Duration(seconds: 12);
const int kMinText = 500;

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

/// 报告里「## 搜到书的源」小节的 URL 列表。
Set<String> _candidatesFromReport(File report) {
  final Set<String> urls = <String>{};
  bool inSection = false;
  for (final String line in report.readAsLinesSync()) {
    if (line.startsWith('## ')) {
      inSection = line.contains('搜到书的源');
      continue;
    }
    if (!inSection) continue;
    final List<String> parts = line.split(' | ');
    if (parts.length >= 2) urls.add(parts[1].trim());
  }
  return urls;
}

void main() {
  test('筛出全文可用的书源并落盘', () async {
    final Set<String> cand = _candidatesFromReport(File('tool/scan_report.txt'));
    stdout.writeln('candidates=${cand.length}');

    // 把候选 URL → 原始规则 JSON
    final Map<String, Map<String, dynamic>> pool = <String, Map<String, dynamic>>{};
    for (final FileSystemEntity e in Directory('tool/scan_raw').listSync()) {
      if (e is! File || !e.path.toLowerCase().endsWith('.json')) continue;
      Object? json;
      try {
        json = jsonDecode(utf8.decode(e.readAsBytesSync(), allowMalformed: true));
      } catch (_) {
        continue;
      }
      for (final Map<String, dynamic> m in _extract(json)) {
        final Object? u = m['bookSourceUrl'];
        if (u is! String) continue;
        if (!cand.contains(u.trim())) continue;
        pool.putIfAbsent(u.trim(), () => m);
      }
    }
    stdout.writeln('matched=${pool.length}');

    final List<Map<String, dynamic>> live = <Map<String, dynamic>>[];
    final StringBuffer log = StringBuffer();

    for (final MapEntry<String, Map<String, dynamic>> e in pool.entries) {
      final BookSource src = BookSource.fromJson(e.value);
      final SourceEngine engine =
          SourceEngine(http: HttpService(timeout: kTimeout));
      final String name = src.name;
      try {
        final List<dynamic> hits = await engine.search(src, kKeyword);
        if (hits.isEmpty) {
          log.writeln('SKIP $name | 搜索 0 条');
          continue;
        }
        final dynamic first = hits.first;
        final String bookUrl = first.bookUrl as String;
        final BookInfo info = await engine.bookInfo(src, bookUrl);
        final List<BookChapter> chs =
            await engine.chapters(src, info, maxPages: 10);
        if (chs.isEmpty) {
          log.writeln('SKIP $name | 目录为空');
          continue;
        }
        // 取靠后的章节验证正文，避免「简介页」冒充正文
        final BookChapter ch = chs[(chs.length * 3) ~/ 4];
        final BookContent ct = await engine.content(src, ch);
        final int textLen = ct.text.trim().length;
        final int imgCount = ct.images.length;
        if (textLen < kMinText && imgCount == 0) {
          log.writeln('SKIP $name | 正文太短 text=$textLen img=$imgCount');
          continue;
        }
        log.writeln('LIVE $name | 搜索=${hits.length} 目录=${chs.length} '
            '正文=$textLen 图=$imgCount | ${src.url}');
        live.add(<String, dynamic>{
          ...src.raw,
          'bookSourceName': name,
          'bookSourceUrl': src.url,
        });
      } catch (err) {
        log.writeln('SKIP $name | $err'.split('\n').first);
      }
    }

    File('tool/pick_log.txt').writeAsStringSync(log.toString());
    stdout.writeln(log.toString());
    stdout.writeln('live=${live.length}');
    File('docs/live_sources.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(live));
    expect(live, isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 30)));
}
