import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noval/src/model/book_source.dart';
import 'package:noval/src/model/search_book.dart';
import 'package:noval/src/net/http_service.dart';
import 'package:noval/src/source/source_engine.dart';

/// 验证「客户端相关性过滤」：看漫画的搜索接口是按单字模糊匹配的。
void main() {
  const String path = 'docs/live_sources.json';
  LateSource lateSource = LateSource();

  setUpAll(() {
    final dynamic decoded =
        jsonDecode(File(path).readAsStringSync(encoding: utf8));
    final List<dynamic> list = decoded is List<dynamic>
        ? decoded
        : <dynamic>[decoded];
    for (final dynamic item in list) {
      final BookSource s = BookSource.fromJson(item as Map<String, dynamic>);
      if (s.name.contains('kanman')) lateSource.value = s;
    }
  });

  test('看漫画：精确关键词只留相关结果', () async {
    final BookSource src = lateSource.value!;
    final SourceEngine engine = SourceEngine(http: HttpService());
    final List<SearchBook> hits = await engine.search(src, '某天成为王的女儿');
    stdout.writeln('精确搜索 ${hits.length} 条：'
        '${hits.map((SearchBook b) => b.name).take(5).toList()}');
    expect(hits, isNotEmpty);
    expect(hits.every((SearchBook b) => b.name.contains('某天成为王的女儿')),
        isTrue);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('看漫画：站内无此书时原样返回（站点模糊匹配的证据）', () async {
    final BookSource src = lateSource.value!;
    final SourceEngine engine = SourceEngine(http: HttpService());
    final List<SearchBook> hits = await engine.search(src, '大王饶命');
    stdout.writeln('模糊搜索 ${hits.length} 条：'
        '${hits.map((SearchBook b) => b.name).take(5).toList()}');
    expect(hits.any((SearchBook b) => b.name.contains('大王饶命')), isFalse);
  }, timeout: const Timeout(Duration(minutes: 3)));
}

class LateSource {
  BookSource? value;
}
