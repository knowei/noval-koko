import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noval/src/core/rule_exception.dart';
import 'package:noval/src/model/book_source.dart';
import 'package:noval/src/net/http_service.dart';
import 'package:noval/src/source/pica_source.dart';

/// 用本地假服务器把哔咔原生的「签名 / 登录 / 搜索 / 目录 / 图片」全跑一遍。
void main() {
  late HttpServer server;
  late PicaSource pica;
  final List<Map<String, String>> seen = <Map<String, String>>[];

  Map<String, dynamic> ok(Object data) =>
      <String, dynamic>{'code': 200, 'message': 'ok', 'data': data};

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((HttpRequest req) async {
      final String path = req.uri.toString();
      final Map<String, String> headers = <String, String>{};
      req.headers.forEach((String k, List<String> v) {
        headers[k.toLowerCase()] = v.join(',');
      });
      seen.add(<String, String>{'path': path, ...headers});

      Object? body;
      if (path.startsWith('/auth/sign-in')) {
        final String raw = await utf8.decoder.bind(req).join();
        final Map<String, dynamic> reqJson =
            jsonDecode(raw) as Map<String, dynamic>;
        if (reqJson['email'] == 'a@b.c' && reqJson['password'] == 'pw') {
          body = ok(<String, dynamic>{'token': 'T0KEN'});
        } else {
          body = <String, dynamic>{
            'code': 400,
            'message': 'invalid credentials',
          };
          req.response.statusCode = 400;
        }
      } else if (path.startsWith('/users/profile')) {
        body = headers['authorization'] == 'T0KEN'
            ? ok(<String, dynamic>{
                'user': <String, dynamic>{'name': '测试用户'},
              })
            : <String, dynamic>{'code': 401, 'message': 'unauthorized'};
        if (headers['authorization'] != 'T0KEN') {
          req.response.statusCode = 401;
        }
      } else if (path.startsWith('/comics/c1/order/1/pages')) {
        body = ok(<String, dynamic>{
          'pages': <String, dynamic>{
            'page': 1,
            'pages': 1,
            'docs': <Object>[
              <String, dynamic>{
                'media': <String, dynamic>{'path': 'x/1.jpg'},
              },
              <String, dynamic>{'path': 'x/2.jpg'},
            ],
          },
        });
      } else if (path.startsWith('/comics/c1/order')) {
        body = ok(<String, dynamic>{
          'eps': <String, dynamic>{
            'page': 1,
            'pages': 1,
            'total': 2,
            'docs': <Object>[
              <String, dynamic>{'order': 1, 'title': '第1话 开局'},
              <String, dynamic>{'order': 2, 'title': '第2话 觉醒'},
            ],
          },
        });
      } else if (path.startsWith('/comics/c1')) {
        body = ok(<String, dynamic>{
          'comic': <String, dynamic>{
            '_id': 'c1',
            'title': '斗罗大陆',
            'author': '唐家三少',
            'description': '穿越斗罗',
            'categories': <String>['热血', '玄幻'],
            'thumb': <String, dynamic>{'path': 'p/cover.jpg'},
            'updated_at': '2026-10-01',
          },
        });
      } else if (path.startsWith('/comics')) {
        if (headers['authorization'] != 'T0KEN') {
          req.response.statusCode = 401;
          body = <String, dynamic>{'code': 401, 'message': 'unauthorized'};
          req.response.headers.contentType = ContentType.json;
          req.response.write(jsonEncode(body));
          await req.response.close();
          return;
        }
        body = ok(<String, dynamic>{
          'comics': <Object>[
            <String, dynamic>{
              '_id': 'c1',
              'title': '斗罗大陆',
              'author': '唐家三少',
              'description': '穿越斗罗',
              'categories': <String>['热血', '玄幻'],
              'thumb': <String, dynamic>{'path': 'p/cover.jpg'},
            },
          ],
        });
      } else {
        body = <String, dynamic>{'code': 404, 'message': 'not found'};
        req.response.statusCode = 404;
      }
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode(body));
      await req.response.close();
    });
    final int port = server.port;
    final HttpService http = HttpService(proxy: '');
    pica = PicaSource(http, baseUrl: 'http://127.0.0.1:$port');
  });

  tearDownAll(() async {
    await server.close(force: true);
  });

  final BookSource source = BookSource(
    url: 'pica://comic',
    name: '哔咔漫画',
    type: SourceType.image,
    searchUrl: 'pica://search',
  );

  test('签名是 64 位十六进制且同样输入结果稳定', () {
    final String a = pica.sign('GET', '/comics?page=1', '1700000000', 'abc123');
    final String b = pica.sign('GET', '/comics?page=1', '1700000000', 'abc123');
    expect(a, b);
    expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(a), isTrue);
    // 方法/路径/时间戳/nonce 任一变化都必须换签名。
    expect(pica.sign('POST', '/comics?page=1', '1700000000', 'abc123'),
        isNot(a));
    expect(pica.sign('GET', '/comics?page=2', '1700000000', 'abc123'),
        isNot(a));
    expect(pica.sign('GET', '/comics?page=1', '1700000001', 'abc123'),
        isNot(a));
    expect(pica.sign('GET', '/comics?page=1', '1700000000', 'abc124'),
        isNot(a));
  });

  test('登录失败会抛错，登录成功能拿到昵称', () async {
    await expectLater(
      pica.signIn('a@b.c', 'wrong'),
      throwsA(isA<RuleException>()),
    );
    expect(pica.token, isNull);

    final String who = await pica.signIn('a@b.c', 'pw');
    expect(pica.token, 'T0KEN');
    expect(who, 'T0KEN'); // signIn 返回拿到的 token
    expect(await pica.me(), '测试用户');
  });

  test('搜索/详情/目录/图片全链路', () async {
    await pica.signIn('a@b.c', 'pw');
    seen.clear();

    final List<dynamic> hits = await pica.search(source, '斗罗大陆');
    expect(hits.length, 1);
    expect(hits.first.name, '斗罗大陆');
    expect(hits.first.bookUrl, 'pica://comic/c1');
    expect(hits.first.sourceName, '哔咔漫画');
    expect(hits.first.cover, startsWith(PicaSource.imageBase));

    final info = await pica.bookInfo(source, 'pica://comic/c1');
    expect(info.name, '斗罗大陆');
    expect(info.author, '唐家三少');
    expect(info.kind.trim(), '热血 玄幻');

    final chapters = await pica.chapters(source, info);
    expect(chapters.length, 2);
    expect(chapters.first.title, '第1话 开局');
    expect(chapters.first.url, 'pica://comic/c1/1');
    expect(chapters[1].index, 1);

    final content = await pica.content(source, chapters.first);
    expect(content.images.length, 2);
    expect(content.images.first, '${PicaSource.imageBase}x/1.jpg');

    // 每个请求都必须带 api-key / nonce / timestamp / signature，且带上 token。
    for (final Map<String, String> h in seen) {
      expect(h['api-key'], PicaSource.apiKey, reason: h['path']);
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(h['nonce'] ?? ''), isTrue,
          reason: h['path']);
      expect(int.tryParse(h['timestamp'] ?? ''), isNotNull, reason: h['path']);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(h['signature'] ?? ''), isTrue,
          reason: h['path']);
      expect(h['authorization'], 'T0KEN', reason: h['path']);
    }
  });

  test('token 失效时报「请重新登录」', () async {
    pica.token = 'BAD';
    await expectLater(
      pica.search(source, '斗罗大陆'),
      throwsA(isA<RuleException>().having(
        (RuleException e) => e.message,
        'message',
        contains('重新登录'),
      )),
    );
    pica.token = null;
  });
}
