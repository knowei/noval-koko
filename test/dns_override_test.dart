import 'package:flutter_test/flutter_test.dart';
import 'package:noval/src/net/dns_override.dart';
import 'package:noval/src/net/http_service.dart';

/// 真网络冒烟：验证「DNS 覆盖」能让直连（不挂代理）通。
///
/// 跑法（注意不要带 NOVAL_PROXY）：
/// `flutter test test/dns_override_test.dart`
void main() {
  test('DNS 覆盖表命中哔咔/禁漫', () {
    expect(DnsOverride.has('www.picacomic.com'), isTrue);
    expect(DnsOverride.has('18comic.vip'), isTrue);
    expect(DnsOverride.of('www.picacomic.com'), isNotEmpty);
  });

  test('直连哔咔首页应当 200（走 DNS 覆盖，不挂代理）', () async {
    final HttpService http = HttpService(timeout: const Duration(seconds: 20));
    final HttpResult r = await http.request('https://www.picacomic.com/');
    // ignore: avoid_print
    print('picacomic status=${r.statusCode} len=${r.body.length}\n'
        'BODY: ${r.body.substring(0, r.body.length.clamp(0, 400))}');
    expect(r.statusCode, 200);
    expect(r.body.length, greaterThan(1000));
  });

  test('直连禁漫首页能到 Cloudflare（不再超时，被识别为人机验证）', () async {
    final HttpService http = HttpService(timeout: const Duration(seconds: 20));
    await expectLater(
      () => http.request('https://18comic.vip/'),
      throwsA(
        predicate<Object>(
          (Object e) => e.toString().contains('人机验证'),
          '应当识别为 Cloudflare 人机验证，而不是网络超时',
        ),
      ),
    );
  });
}
