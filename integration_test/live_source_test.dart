// 活源回归：docs/live_sources.json 里的源必须始终能跑通「搜索→详情→目录→正文/图片」。
// 跑法：flutter test integration_test/live_source_test.dart -d windows
// 这些是真实站点，随时可能改版；失败即代表该条目已过期，需要换源而不是改引擎。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noval/src/model/book_info.dart';
import 'package:noval/src/model/book_source.dart';
import 'package:noval/src/net/http_service.dart';
import 'package:noval/src/source/source_engine.dart';

const String kKeyword = '剑来';

/// 真实站点会抽风（限流/超时），一次失败不代表源坏了：重试两次再判定。
Future<T> _retry<T>(Future<T> Function() task, [int attempts = 3]) async {
  Object? last;
  for (int i = 0; i < attempts; i++) {
    try {
      return await task();
    } catch (e) {
      last = e;
      await Future<void>.delayed(Duration(milliseconds: 800 * (i + 1)));
    }
  }
  throw last!;
}

void main() {
  final List<dynamic> raw = jsonDecode(
    File('docs/live_sources.json').readAsStringSync(),
  ) as List<dynamic>;

  test('活源清单非空', () {
    expect(raw, isNotEmpty);
  });

  for (final dynamic item in raw) {
    final Map<String, dynamic> map = item as Map<String, dynamic>;
    final BookSource src = BookSource.fromJson(map);
    final Map<String, dynamic> rs =
        (map['ruleSearch'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final String? check = rs['checkKeyWord'] as String?;
    final String keyword = (check != null && check.trim().isNotEmpty)
        ? check.trim()
        : kKeyword;

    test('活源：${src.name}', () async {
      final SourceEngine engine = SourceEngine(
        http: HttpService(timeout: const Duration(seconds: 30)),
      );

      final List<dynamic> hits = await _retry(() => engine.search(src, keyword));
      expect(hits, isNotEmpty, reason: '搜索「$keyword」应当有结果');

      // 前三本书任一本能跑通即算该源可用（有的书本身没内容/未审核）
      final StringBuffer log = StringBuffer();
      bool ok = false;
      for (final dynamic hit in hits.take(3)) {
        if (ok) break;
        BookInfo info;
        List<BookChapter> chs;
        try {
          info = await _retry(() => engine.bookInfo(
            src,
            hit.bookUrl as String,
            fallbackName: hit.name as String,
            fallbackAuthor: hit.author as String,
          ));
          if (info.name.trim().isEmpty) continue;
          chs = await _retry(() => engine.chapters(src, info, maxPages: 10));
        } catch (e) {
          log.writeln('《${hit.name}》详情/目录失败：$e');
          continue;
        }
        log.writeln('《${info.name}》目录 ${chs.length} 章');
        if (chs.isEmpty) continue;

        // 部分章节可能是空的（站点标记未审核/防盗），就近多试几章
        final int mid = (chs.length * 3) ~/ 4;
        for (int i = mid; i < chs.length && i < mid + 4 && !ok; i++) {
          try {
            final BookContent ct = await _retry(() => engine.content(src, chs[i]));
            if (src.type == 2) {
              ok = ct.images.isNotEmpty;
            } else {
              ok = ct.text.trim().length > 300;
            }
            log.writeln('  第 ${i + 1} 章 ok=$ok');
          } catch (e) {
            log.writeln('  第 ${i + 1} 章失败：$e');
          }
        }
      }
      expect(ok, isTrue, reason: '正文/图片应当能取到\n$log');
    }, timeout: const Timeout(Duration(minutes: 6)));
  }
}
