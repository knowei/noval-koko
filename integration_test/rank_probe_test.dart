// 搜索相关性排序验证：搜「神秘复苏」，看完全匹配是否排最前
// 跑法：flutter test integration_test/rank_probe_test.dart -d windows
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noval/src/model/book_source.dart';
import 'package:noval/src/model/search_book.dart';
import 'package:noval/src/net/http_service.dart';
import 'package:noval/src/source/source_engine.dart';

void main() {
  test('相关性排序：完全匹配优先', () async {
    final List<dynamic> arr =
        jsonDecode(File('docs/live_sources.json').readAsStringSync())
            as List<dynamic>;
    final List<BookSource> sources = arr
        .map((dynamic e) => BookSource.fromJson(e as Map<String, dynamic>))
        .toList();

    final SourceEngine engine =
        SourceEngine(http: HttpService(timeout: const Duration(seconds: 25)));
    final StringBuffer log = StringBuffer();
    for (final BookSource s in sources) {
      if (s.type == 2) continue; // 先只看文字源
      try {
        final List<SearchBook> hits = await engine.search(s, '神秘复苏');
        if (hits.isEmpty) continue;
        log.writeln('== ${s.name} 共 ${hits.length} 条');
        for (final SearchBook b in hits.take(8)) {
          log.writeln('   ${b.name}');
        }
      } catch (e) {
        log.writeln('== ${s.name} ERR $e');
      }
    }
    File('tool/rank_result.txt').writeAsStringSync(log.toString());
  }, timeout: const Timeout(Duration(minutes: 10)));
}
