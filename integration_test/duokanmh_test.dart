import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:noval/src/core/text_util.dart';
import 'package:noval/src/model/book_info.dart';
import 'package:noval/src/model/book_source.dart';
import 'package:noval/src/model/search_book.dart';
import 'package:noval/src/source/source_engine.dart';

/// 多看漫画（duokanmh.com）：搜索 → 详情 → 目录 → 章节图（站点自带解密器）。
///
/// 目录是纯 HTML（681 章一次给全）；章节图地址被加密在 `var params` 里，
/// 由站点自己的 cms-2.0.1.min.js + crypto-js 在 QuickJS 里解密。
///
/// 运行：
///   Stop-Process noval
///   flutter test integration_test/duokanmh_test.dart -d windows
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('多看漫画：搜索/详情/目录/图片', () async {
    final SourceEngine engine = SourceEngine();
    final BookSource source = BookSource.fromJson(
      jsonDecode(File('sample_sources/duokanmh.json').readAsStringSync())
          as Map<String, dynamic>,
    );

    final List<SearchBook> hits = await engine.search(source, '斗破苍穹');
    expect(hits, isNotEmpty, reason: '搜索应当有结果');
    final SearchBook first = hits.first;

    final BookInfo info = await engine.bookInfo(source, first.bookUrl);
    expect(info.name, isNotEmpty, reason: '详情书名不能为空');
    expect(info.author, isNotEmpty, reason: '详情作者不能为空');

    final List<BookChapter> chapters = await engine.chapters(source, info);
    expect(chapters.length, greaterThan(100), reason: '斗破苍穹应有数百章');

    // 抽新章节验证图片解密链路（多章各解一次，确认解密器可重复使用）
    for (final int idx in <int>[math.min(30, chapters.length - 1), chapters.length - 1]) {
      final BookChapter target = chapters[idx];
      final BookContent content = await engine.content(source, target);
      expect(content.images, isNotEmpty, reason: '${target.title} 应能解出图片');
      final List<int> bytes = await engine.http.imageBytes(
        content.images.first,
        headers: TextUtil.imageHeaders(
          content.images.first,
          referer: content.referer,
        ),
      );
      expect(bytes.length, greaterThan(3000), reason: '首图应是真图');
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}
