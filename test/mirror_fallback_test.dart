import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noval/src/model/book_source.dart';
import 'package:noval/src/model/search_book.dart';
import 'package:noval/src/net/http_service.dart';
import 'package:noval/src/source/source_engine.dart';

import 'mock_http_adapter.dart';

const String _searchHtml = '''
<html><body>
<div class="item"><a href="/book/1">镜像里的书</a></div>
</body></html>
''';

BookSource _source({List<String> mirrors = const <String>[]}) {
  return BookSource.fromJson(<String, dynamic>{
    'bookSourceUrl': 'https://dead.example',
    'bookSourceName': '镜像测试',
    'bookSourceType': 0,
    'searchUrl': '/s?q={{key}}',
    'mirrors': mirrors,
    'ruleSearch': <String, dynamic>{
      'bookList': '@css:.item',
      'name': '@css:a@text',
      'bookUrl': '@css:a@href',
    },
  });
}

void main() {
  test('主域连不上时自动换镜像，并把搜索结果拿回来', () async {
    final MockHttpAdapter adapter = MockHttpAdapter((RequestOptions o) {
      final String host = o.uri.host;
      if (host == 'dead.example') {
        throw DioException.connectionError(
          requestOptions: o,
          reason: '模拟：连接被重置',
        );
      }
      return mockHtml(_searchHtml);
    });

    final SourceEngine engine = SourceEngine(
      http: HttpService(adapter: adapter),
    );
    final List<SearchBook> books =
        await engine.search(_source(mirrors: <String>['https://alive.example']), '剑来');

    expect(books.length, 1);
    expect(books.first.name, '镜像里的书');
    // 两个域名都试过，且先试的是书源自己的地址
    expect(adapter.log.first.uri.host, 'dead.example');
    expect(adapter.log.last.uri.host, 'alive.example');
    // 相对路径被解析到活着的那台机器上
    expect(books.first.bookUrl, startsWith('https://alive.example'));
  });

  test('镜像都不行时抛出可读错误，不吞掉原因', () async {
    final MockHttpAdapter adapter = MockHttpAdapter((RequestOptions o) {
      throw DioException.connectionError(
        requestOptions: o,
        reason: '模拟：整段被墙',
      );
    });

    final SourceEngine engine = SourceEngine(
      http: HttpService(adapter: adapter),
    );

    await expectLater(
      engine.search(_source(mirrors: <String>['https://also-dead.example']), '剑来'),
      throwsA(
        isA<Exception>().having(
          (Exception e) => e.toString(),
          'message',
          contains('网络请求失败'),
        ),
      ),
    );
  });
}
