import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noval/src/core/text_util.dart';
import 'package:noval/src/net/http_service.dart';
import 'package:noval/src/net/net_diag.dart';

void main() {
  test('hostsOf 从书源 JSON 里抽出域名并去重排序', () {
    final List<String> hosts = NetDiag.hostsOf(<String>[
      '{"bookSourceUrl":"https://www.kepub.net",'
          '"searchUrl":"/search/all?keyword={{key}}"}',
      'https://www.linovelib.com/novel/2013/catalog',
      'http://127.0.0.1:8787/search',
      'https://example.com/x',
    ]);
    expect(hosts, <String>['www.kepub.net', 'www.linovelib.com']);
  });

  test('imageUrlVariants 给出同组镜像，非已知图床只有原地址', () {
    const String baozimh = 'https://c-nd2-1.6wm.top/coco/1/a.webp';
    final List<String> variants = TextUtil.imageUrlVariants(baozimh);
    expect(variants.first, baozimh);
    expect(variants.length, greaterThan(1));
    expect(variants, contains('https://c-nd3-1.6wm.top/coco/1/a.webp'));

    const String other = 'https://img.example.org/a.jpg';
    expect(TextUtil.imageUrlVariants(other), <String>[other]);
  });

  test('looksLikeChallenge 能认出 Cloudflare 验证页', () {
    final Headers cf = Headers.fromMap(<String, List<String>>{
      'server': <String>['cloudflare'],
    });
    expect(
      HttpService.looksLikeChallenge(
        '<html><head><title>Just a moment...</title></head></html>',
        cf,
      ),
      isTrue,
    );

    final Headers mitigated = Headers.fromMap(<String, List<String>>{
      'cf-mitigated': <String>['challenge'],
    });
    expect(HttpService.looksLikeChallenge('{}', mitigated), isTrue);

    final Headers normal = Headers.fromMap(<String, List<String>>{
      'server': <String>['nginx'],
    });
    expect(
      HttpService.looksLikeChallenge(
        '<html><h1>404 Not Found</h1></html>',
        normal,
      ),
      isFalse,
    );
  });
}
