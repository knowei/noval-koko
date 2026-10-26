import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noval/src/core/text_util.dart';
import 'package:noval/src/model/book_source.dart';
import 'package:noval/src/model/search_book.dart';
import 'package:noval/src/net/http_service.dart';
import 'package:noval/src/source/source_engine.dart';

/// 体检：`docs/live_sources.json` 里每个源的搜索结果到底带不带封面，
/// 封面地址能不能真的下到图片。
///
/// 跑法：flutter test integration_test/cover_probe_test.dart -d windows
/// 结果写 tool/cover_report.txt
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final List<dynamic> raw = jsonDecode(
    File('docs/live_sources.json').readAsStringSync(),
  ) as List<dynamic>;

  testWidgets('每个源的封面体检', (WidgetTester tester) async {
    final Dio dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      validateStatus: (int? s) => s != null && s < 500,
      followRedirects: true,
    ));
    final StringBuffer log = StringBuffer();

    for (final dynamic item in raw) {
      final Map<String, dynamic> map = item as Map<String, dynamic>;
      final BookSource source = BookSource.fromJson(map);
      final String keyword = _keywordOf(map);
      final SourceEngine engine = SourceEngine(
        http: HttpService(timeout: const Duration(seconds: 30)),
      );
      final String head = '[${source.name}] keyword=$keyword';
      try {
        final List<SearchBook> books = await engine.search(source, keyword);
        if (books.isEmpty) {
          log.writeln('$head → 搜到 0 条');
          continue;
        }
        final SearchBook first = books.first;
        if (first.cover.trim().isEmpty) {
          log.writeln('$head → ${books.length} 条，但**规则没取到封面**'
              '（《${first.name}》）');
          continue;
        }
        final Response<List<int>> r = await dio.get<List<int>>(
          first.cover,
          options: Options(
            responseType: ResponseType.bytes,
            headers: TextUtil.imageHeaders(first.cover),
          ),
        );
        final List<int> data = r.data ?? <int>[];
        log.writeln('$head → ${books.length} 条 | 《${first.name}》'
            ' | ${first.cover}'
            ' | HTTP ${r.statusCode}'
            ' | ${r.headers.value('content-type')}'
            ' | ${data.length} B | ${_kindOf(data)}');
      } catch (e) {
        log.writeln('$head → 失败：$e');
      } finally {
        engine.dispose();
      }
    }

    File('tool/cover_report.txt')
        .writeAsStringSync(log.toString(), encoding: utf8);
    expect(log.toString(), isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 5)));
}

String _keywordOf(Map<String, dynamic> map) {
  final Map<String, dynamic> rs =
      (map['ruleSearch'] as Map<String, dynamic>?) ?? <String, dynamic>{};
  final String? check = rs['checkKeyWord'] as String?;
  return (check != null && check.trim().isNotEmpty) ? check.trim() : '剑来';
}

String _kindOf(List<int> data) {
  if (data.length < 4) return '空响应';
  final String hex = data
      .take(4)
      .map((int b) => b.toRadixString(16).padLeft(2, '0'))
      .join(' ');
  if (hex.startsWith('ff d8 ff')) return 'JPEG ✓';
  if (hex.startsWith('89 50 4e 47')) return 'PNG ✓';
  if (hex.startsWith('52 49 46 46')) return 'WEBP ✓';
  if (hex.startsWith('47 49 46')) return 'GIF ✓';
  if (data.first == 0x3c) return 'HTML（不是图片）✗';
  return '未知($hex)';
}
