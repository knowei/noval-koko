import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:integration_test/integration_test.dart';
import 'package:noval/src/db/source_repo.dart';
import 'package:noval/src/model/book_source.dart';
import 'package:noval/src/net/http_service.dart';
import 'package:noval/src/source/source_engine.dart';

/// 批量排障：直接打搜索请求，看「请求是否被接受 / 选择器是否命中」。
///
///   $env:PROBE_SOURCE_FILE='sample_sources/yijie_bookSource.json'
///   $env:PROBE_INDICES='7,8,15,24,26'
///   $env:PROBE_DETAIL='7'      # 可选：对某个源打印详细选择器信息
///   flutter test integration_test/debug_source_test.dart -d windows
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('批量排障', (WidgetTester tester) async {
    final String file = Platform.environment['PROBE_SOURCE_FILE'] ??
        'sample_sources/yijie_bookSource.json';
    final String idxEnv = Platform.environment['PROBE_INDICES'] ?? '0';
    final String detailIdx = Platform.environment['PROBE_DETAIL'] ?? '';
    final String keyword = Platform.environment['PROBE_KEYWORD'] ?? '剑来';
    final List<int> indices = idxEnv
        .split(',')
        .map((String s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toList();

    final List<BookSource> sources =
        SourceRepo.parseSources(await File(file).readAsString());
    final HttpService http = HttpService();

    for (final int index in indices) {
      if (index < 0 || index >= sources.length) continue;
      final BookSource source = sources[index];
      final bool detail = index.toString() == detailIdx;
      // ignore: avoid_print
      print('==== [$index] ${source.name} | ${source.url}');

      final _Spec spec = _Spec.of(source, keyword);
      if (detail) {
        // ignore: avoid_print
        print('  searchUrl(${spec.method}) ${spec.url}');
        // ignore: avoid_print
        print('  body=${spec.body} charset=${spec.charset}');
        // ignore: avoid_print
        print('  bookList=${source.ruleSearch.bookList}');
      }

      HttpResult res;
      try {
        res = await http.request(
          spec.url,
          method: spec.method,
          body: spec.body.isEmpty ? null : spec.body,
          charset: spec.charset.isEmpty ? null : spec.charset,
          headers: <String, String>{...source.header, 'Referer': source.url},
        );
      } catch (e) {
        // ignore: avoid_print
        print('  ERR 请求异常: $e');
        continue;
      }

      final bool hasKey = res.body.contains(keyword);
      final doc = html_parser.parse(res.body);
      final String listRule = _stripPrefix(source.ruleSearch.bookList);
      int hits = -1;
      String firstItem = '';
      if (listRule.isNotEmpty) {
        try {
          final String sel = listRule.split('@').first;
          final els = doc.querySelectorAll(sel);
          hits = els.length;
          if (els.isNotEmpty) {
            final String html = els.first.outerHtml;
            firstItem = html.length > 320 ? html.substring(0, 320) : html;
          }
        } catch (e) {
          hits = -2;
        }
      }
      // ignore: avoid_print
      print('  HTTP ${res.statusCode} len=${res.body.length} 含关键词=$hasKey '
          '列表命中=$hits');
      if (detail || hits > 0) {
        if (firstItem.isNotEmpty) {
          // ignore: avoid_print
          print('  首项: ${firstItem.replaceAll('\n', ' ')}');
        } else {
          // ignore: avoid_print
          print('  开头: ${res.body.substring(0, res.body.length > 300 ? 300 : res.body.length).replaceAll('\n', ' ')}');
        }
      }

      if (detail) {
        final SourceEngine engine = SourceEngine();
        try {
          final search = await engine.search(source, keyword);
          // ignore: avoid_print
          print('  引擎结果: ${search.length} 条');
          for (final b in search.take(3)) {
            // ignore: avoid_print
            print('    ${b.name} | ${b.author} | ${b.bookUrl}');
          }
        } catch (e) {
          // ignore: avoid_print
          print('  引擎异常: $e');
        }
      }
    }
    expect(true, isTrue);
  });
}

String _stripPrefix(String rule) {
  String r = rule.trim();
  if (r.toLowerCase().startsWith('@css:')) r = r.substring(5).trim();
  return r;
}

class _Spec {
  _Spec(this.url, this.method, this.body, this.charset);

  final String url;
  final String method;
  final String body;
  final String charset;

  static _Spec of(BookSource source, String keyword) {
    final String rawUrl = source.searchUrl;
    final int optIdx = rawUrl.lastIndexOf(',{');
    Map<String, dynamic> options = <String, dynamic>{};
    String base = rawUrl;
    if (optIdx > 0 && rawUrl.trimRight().endsWith('}')) {
      try {
        final Object? parsed = jsonDecode(rawUrl.substring(optIdx + 1));
        if (parsed is Map<String, dynamic>) {
          options = parsed;
          base = rawUrl.substring(0, optIdx);
        }
      } catch (_) {}
    }
    String sub(String tpl, {required bool encode}) {
      final String k = encode ? Uri.encodeQueryComponent(keyword) : keyword;
      return tpl
          .replaceAll('{{key}}', k)
          .replaceAll('{{page}}', '1')
          .replaceAll('searchKey', k)
          .replaceAll('searchPage', '1');
    }

    final String url = base.contains('://')
        ? sub(base, encode: true)
        : Uri.parse(source.url).resolve(sub(base, encode: true)).toString();
    return _Spec(
      url,
      (options['method']?.toString() ?? 'GET').toUpperCase(),
      sub(options['body']?.toString() ?? '', encode: false),
      options['charset']?.toString() ?? '',
    );
  }
}
