import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noval/src/app_state.dart';
import 'package:noval/src/model/book_info.dart';
import 'package:noval/src/model/book_source.dart';
import 'package:noval/src/net/http_service.dart';
import 'package:noval/src/source/source_engine.dart';
import 'package:noval/src/source/source_health.dart';

import 'mock_http_adapter.dart';

const String _searchHtml = '''
<html><body>
<div class="item"><a href="/book/1">剑来</a></div>
<div class="item"><a href="/book/2">雪中悍刀行</a></div>
</body></html>
''';

const String _searchEmpty = '<html><body><div class="none">没有结果</div></body></html>';

const String _detailHtml = '''
<html><body>
<h1>剑来</h1>
<span class="au">烽火戏诸侯</span>
<a class="toc" href="/toc/1">目录</a>
</body></html>
''';

const String _tocHtml = '''
<html><body>
<div class="ch"><a href="/ch/1">第一章 惊蛰</a></div>
<div class="ch"><a href="/ch/2">第二章 开门</a></div>
</body></html>
''';

const String _contentHtml = '''
<html><body><div id="c">大千世界，无奇不有。我陈平安，唯有一剑，可搬山，倒海，降妖，镇魔，
敕神，摘星，断江，摧城，开天。这一段要够长，才不会被判成空正文，所以再多写一点点内容，
凑够一百二十个字以上，确保体检结论是「可读」而不是「正文为空」。再补一段同样的废话，
把字数稳稳地推到两百字以上，避免因为计数口径（含标点、去空白）不一样导致边界失败。
这一句只是为了长度：风吹过小镇的石板路，屋檐下的灯笼晃了一下，然后一切归于安静。</div></body></html>
''';

const String _contentEmpty = '<html><body><div id="other">没有正文</div></body></html>';

BookSource _source() {
  return BookSource.fromJson(<String, dynamic>{
    'bookSourceUrl': 'https://site.example',
    'bookSourceName': '体检测试源',
    'bookSourceType': 0,
    'searchUrl': '/s?q={{key}}',
    'ruleSearch': <String, dynamic>{
      'bookList': '@css:.item',
      'name': '@css:a@text',
      'bookUrl': '@css:a@href',
    },
    'ruleBookInfo': <String, dynamic>{
      'name': '@css:h1@text',
      'author': '@css:.au@text',
      'tocUrl': '@css:a.toc@href',
    },
    'ruleToc': <String, dynamic>{
      'chapterList': '@css:.ch',
      'chapterName': '@css:a@text',
      'chapterUrl': '@css:a@href',
    },
    'ruleContent': <String, dynamic>{
      'content': '@css:#c@text',
    },
  });
}

AppState _state(MockHandler handler) {
  final AppState state = AppState();
  state.engine = SourceEngine(
    http: HttpService(adapter: MockHttpAdapter(handler)),
  );
  return state;
}

MockReply Function(RequestOptions) _site({bool emptySearch = false, bool emptyContent = false}) {
  return (RequestOptions o) {
    final String path = o.uri.path;
    if (path == '/s') return mockHtml(emptySearch ? _searchEmpty : _searchHtml);
    if (path == '/book/1') return mockHtml(_detailHtml);
    if (path == '/toc/1') return mockHtml(_tocHtml);
    if (path.startsWith('/ch/')) {
      return mockHtml(emptyContent ? _contentEmpty : _contentHtml);
    }
    return MockReply(404, 'not found');
  };
}

void main() {
  group('书源体检分级', () {
    test('搜索请求失败 → 网络失败', () async {
      final AppState state = _state((RequestOptions o) {
        throw DioException.connectionError(
          requestOptions: o,
          reason: '模拟：连接被重置',
        );
      });
      final SourceHealth h = await state.checkSource(_source());
      expect(h.stage, SourceStage.networkFail);
      expect(h.failed, isTrue);
      expect(h.readable, isFalse);
      expect(h.note, contains('搜索请求失败'));
    });

    test('搜索通了但 0 条 → 搜索无结果（不再算可用）', () async {
      final AppState state = _state(_site(emptySearch: true));
      final SourceHealth h = await state.checkSource(_source());
      expect(h.stage, SourceStage.emptyResult);
      expect(h.failed, isTrue);
      expect(h.hits, 0);
    });

    test('批量轻检只验到搜索有结果 → 仅搜索通过', () async {
      final AppState state = _state(_site());
      final SourceHealth h = await state.checkSource(_source());
      expect(h.stage, SourceStage.searchOnly);
      expect(h.hits, 2);
      // 只测了搜索，不能宣称可读
      expect(h.readable, isFalse);
      expect(h.failed, isFalse);
      expect(h.label, '仅搜索通过');
    });

    test('单源深检走完详情→目录→正文 → 可读', () async {
      final AppState state = _state(_site());
      final SourceHealth h = await state.checkSource(_source(), deep: true);
      expect(h.stage, SourceStage.readable);
      expect(h.readable, isTrue);
      expect(h.hits, 2);
      expect(h.chapters, 2);
      expect(h.textLength, greaterThan(120));
      expect(h.detail, contains('目录 2 章'));
    });

    test('正文为空 → 正文失败（这正是以前被误判成可用的情形）', () async {
      final AppState state = _state(_site(emptyContent: true));
      final SourceHealth h = await state.checkSource(_source(), deep: true);
      expect(h.stage, SourceStage.contentFail);
      expect(h.failed, isTrue);
      expect(h.readable, isFalse);
      expect(h.note, contains('正文为空'));
    });
  });

  group('正文整理不能丢字段', () {
    test('finalizeContent 拍平正文但保留 referer/images/nextUrl', () {
      const BookContent raw = BookContent(
        text: '<p>第一段</p><p>第二段</p>',
        images: <String>['https://img.example/1.jpg'],
        nextUrl: 'https://site.example/ch/2',
        title: '第一章',
        referer: 'https://site.example/',
      );
      final BookContent out = AppState.finalizeContent(raw);
      expect(out.text, contains('第一段'));
      expect(out.text, isNot(contains('<p>')));
      // 漫画图床要的 Referer 必须原样带出去
      expect(out.referer, 'https://site.example/');
      expect(out.images, raw.images);
      expect(out.nextUrl, raw.nextUrl);
      expect(out.title, raw.title);
    });
  });
}
