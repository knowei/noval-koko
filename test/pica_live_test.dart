import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noval/src/core/rule_exception.dart';
import 'package:noval/src/model/book_source.dart';
import 'package:noval/src/net/http_service.dart';
import 'package:noval/src/source/pica_source.dart';

/// 哔咔真实账号联调（默认跳过）。
///
/// 跑法：
/// ```
/// $env:NOVAL_PICA_EMAIL='你的账号'
/// $env:NOVAL_PICA_PASSWORD='你的密码'
/// flutter test test\pica_live_test.dart
/// ```
/// 账号密码只从环境变量读，不写进仓库。
void main() {
  final String email = Platform.environment['NOVAL_PICA_EMAIL'] ?? '';
  final String password = Platform.environment['NOVAL_PICA_PASSWORD'] ?? '';
  final bool missing = email.isEmpty || password.isEmpty;

  final BookSource source = BookSource(
    url: 'pica://comic',
    name: '哔咔漫画',
    type: SourceType.image,
    searchUrl: 'pica://search',
  );

  test('真实登录 + 搜索 + 目录 + 图片', () async {
    final PicaSource pica = PicaSource(HttpService(proxy: ''));
    final String token = await pica.signIn(email, password);
    expect(token.length > 10, isTrue, reason: '应拿到 token');

    final String who = await pica.me();
    // ignore: avoid_print
    print('登录成功，昵称=$who');

    final List<dynamic> hits = await pica.search(source, '斗罗大陆');
    // ignore: avoid_print
    print('搜索「斗罗大陆」=> ${hits.length} 条');
    for (final dynamic h in hits.take(3)) {
      // ignore: avoid_print
      print('  · ${h.name} / ${h.author} / ${h.bookUrl}');
    }
    expect(hits, isNotEmpty, reason: '搜索应该有结果');

    final dynamic first = hits.first;
    final dynamic info = await pica.bookInfo(source, first.bookUrl);
    // ignore: avoid_print
    print('详情：${info.name} 作者=${info.author} 分类=${info.kind} 封面=${info.cover}');

    final List<dynamic> chapters = await pica.chapters(source, info);
    // ignore: avoid_print
    print('目录：${chapters.length} 章，首章=${chapters.first.title}');
    expect(chapters, isNotEmpty);

    try {
      final dynamic content = await pica.content(source, chapters.first);
      // ignore: avoid_print
      print('首章图片：${content.images.length} 张，示例=${content.images.isEmpty ? '' : content.images.first}');
      if (content.images.isNotEmpty) {
        final HttpResult img = await HttpService(proxy: '').request(
          content.images.first as String,
          headers: <String, String>{
            'Referer': 'https://picaapi.picacomic.com/',
          },
        );
        // ignore: avoid_print
        print('首图下载：HTTP ${img.statusCode}，${img.body.length} 字符');
      }
    } on RuleException catch (e) {
      // ignore: avoid_print
      print('取图片失败（可能是该话无图或需要跳过）：$e');
    }
  }, skip: missing ? '未提供 NOVAL_PICA_EMAIL / NOVAL_PICA_PASSWORD' : false);
}
